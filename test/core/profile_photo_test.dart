import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/config/app_config.dart';
import 'package:sahayatri_care_connect/core/media/photo_picker.dart';
import 'package:sahayatri_care_connect/core/media/profile_photo.dart';
import 'package:sahayatri_care_connect/core/widgets/profile_photo_field.dart';

import '../l10n_harness.dart';

/// Profile photos: the pieces that have no screen of their own.
///
/// The API has had `POST|DELETE /uploads/{patients|therapists}/{id}/photo` for
/// some time; the mobile "Change photo" button said "not available yet". These
/// pin the contract the app now speaks to it -- the path, the multipart field
/// name, the extension the server insists on -- because every one of those is
/// the kind of thing that fails as a bare 400 on a real phone and nowhere in a
/// test.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.status = 200, this.body = '{"url":"/api/v1/x"}'});

  final int status;
  final String body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A real 1x1 PNG, so the avatar can decode it. Four arbitrary bytes are fine
/// for the upload tests but make `Image.memory` throw while it is on screen.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

PickedPhoto _photo([String name = 'me.jpg']) =>
    PickedPhoto(bytes: _pngBytes, filename: name);

void main() {
  group('the filename the server will accept', () {
    String name(String n, {String? mime}) =>
        ImagePickerPhotoPicker.uploadFilename(n, mimeType: mime);

    test('leaves a good name alone', () {
      expect(name('me.jpg'), 'me.jpg');
      expect(name('Photo.PNG'), 'Photo.PNG');
      expect(name('a.webp'), 'a.webp');
    });

    test('adds an extension when a cloud gallery supplied none', () {
      // The endpoint checks the name, not the content: an extension-less
      // picture is refused as "only image files are allowed".
      expect(name('image_picker_8812'), 'image_picker_8812.jpg');
      expect(name('image_picker_8812', mime: 'image/png'), 'image_picker_8812.png');
    });

    test('replaces an extension the server does not take', () {
      expect(name('scan.heic'), 'scan.jpg');
      expect(name('scan.tiff', mime: 'image/webp'), 'scan.webp');
    });

    test('survives an empty name', () {
      expect(name(''), 'photo.jpg');
    });
  });

  group('resolving a media path', () {
    test('puts the host in front of a server-relative path', () {
      final url = AppConfig.resolveMediaUrl('/api/v1/uploads/patients/p1/a.jpg?size=3');
      expect(url, startsWith(AppConfig.baseUrl));
      expect(url, endsWith('/api/v1/uploads/patients/p1/a.jpg?size=3'));
      expect(url, isNot(contains('//api')));
    });

    test('adds the slash a bare path is missing', () {
      expect(
        AppConfig.resolveMediaUrl('api/v1/x.jpg'),
        '${AppConfig.baseUrl}/api/v1/x.jpg',
      );
    });

    test('leaves an absolute URL as it is', () {
      expect(
        AppConfig.resolveMediaUrl('https://cdn.example.com/a.jpg'),
        'https://cdn.example.com/a.jpg',
      );
    });
  });

  group('uploading', () {
    ProfilePhotoRepository repo(_RecordingAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = adapter;
      return ProfilePhotoRepository(dio);
    }

    test('a patient photo is a multipart POST to the patient endpoint', () async {
      final adapter = _RecordingAdapter();
      final result = await repo(adapter).upload(
        owner: PhotoOwner.patient,
        ownerId: 'user-1',
        photo: _photo(),
      );

      expect(result.isRight(), isTrue);
      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/uploads/patients/user-1/photo');
      final form = adapter.last!.data as FormData;
      expect(form.files.single.key, 'file', reason: 'the field the API reads');
      expect(form.files.single.value.filename, 'me.jpg');
      expect(form.files.single.value.length, _pngBytes.length);
    });

    test('a therapist photo goes to the therapist endpoint', () async {
      final adapter = _RecordingAdapter();
      await repo(adapter).upload(
        owner: PhotoOwner.therapist,
        ownerId: 'user-2',
        photo: _photo('t.png'),
      );

      expect(adapter.last!.path, '/uploads/therapists/user-2/photo');
    });

    test('hands back the URL the server stored it at', () async {
      final adapter = _RecordingAdapter(
        body: jsonEncode({'url': '/api/v1/uploads/patients/p/photo-ab.jpg'}),
      );
      final result = await repo(adapter).upload(
        owner: PhotoOwner.patient,
        ownerId: 'u',
        photo: _photo(),
      );

      expect(result.getRight().toNullable(), '/api/v1/uploads/patients/p/photo-ab.jpg');
    });

    test('a refusal is a failure carrying the server message', () async {
      final adapter = _RecordingAdapter(
        status: 400,
        body: jsonEncode({'detail': 'File content does not match its type'}),
      );
      final result = await repo(adapter).upload(
        owner: PhotoOwner.patient,
        ownerId: 'u',
        photo: _photo(),
      );

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!.message, contains('does not match'));
    });

    test('a reply with no url is not a success', () async {
      final result = await repo(_RecordingAdapter(body: '{}')).upload(
        owner: PhotoOwner.patient,
        ownerId: 'u',
        photo: _photo(),
      );

      expect(result.isLeft(), isTrue);
    });

    test('removing is a DELETE on the same path', () async {
      final adapter = _RecordingAdapter(body: '{"success":true}');
      final result = await repo(adapter).remove(
        owner: PhotoOwner.patient,
        ownerId: 'user-1',
      );

      expect(result.isRight(), isTrue);
      expect(adapter.last!.method, 'DELETE');
      expect(adapter.last!.path, '/uploads/patients/user-1/photo');
    });
  });

  group('the draft', () {
    test('starts with nothing to send', () {
      expect(ProfilePhotoDraft.untouched.changed, isFalse);
    });

    test('a picked photo is a change, and replaces a removal', () {
      final removed = ProfilePhotoDraft.untouched.withRemoval;
      expect(removed.changed, isTrue);
      final picked = removed.withPicked(_photo());
      expect(picked.picked, isNotNull);
      expect(picked.remove, isFalse, reason: 'a replacement is not a deletion');
    });

    test('nothing is committed when nothing was asked for', () async {
      final repo = ProfilePhotoRepository(Dio());
      final result = await commitProfilePhoto(
        repo,
        owner: PhotoOwner.patient,
        ownerId: 'u',
        draft: ProfilePhotoDraft.untouched,
      );
      expect(result.getRight().toNullable(), isFalse);
    });
  });

  group('the Change photo control', () {
    PickedPhoto? chosen;

    Future<List<ProfilePhotoDraft>> pump(
      WidgetTester tester, {
      String? currentUrl,
      ProfilePhotoDraft draft = ProfilePhotoDraft.untouched,
      PhotoPicker? picker,
    }) async {
      final changes = <ProfilePhotoDraft>[];
      await pumpLocalized(
        tester,
        Scaffold(
          body: ProfilePhotoField(
            initials: 'AR',
            currentUrl: currentUrl,
            draft: draft,
            onChanged: changes.add,
          ),
        ),
        overrides: [
          photoPickerProvider.overrideWithValue(picker ?? _FakePicker(chosen)),
        ],
      );
      await tester.pumpAndSettle();
      return changes;
    }

    setUp(() => chosen = _photo('chosen.jpg'));

    testWidgets('opens a sheet offering the camera and the gallery', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();

      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
    });

    testWidgets('does not offer Remove when there is nothing to remove', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();

      expect(find.text('Remove photo'), findsNothing);
    });

    testWidgets('offers Remove when there is a photo', (tester) async {
      await pump(tester, currentUrl: '/api/v1/uploads/patients/p/a.jpg');
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();

      expect(find.text('Remove photo'), findsOneWidget);
    });

    testWidgets('picking from the gallery reports the photo', (tester) async {
      final changes = await pump(tester);
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();

      expect(changes, hasLength(1));
      expect(changes.single.picked!.filename, 'chosen.jpg');
    });

    testWidgets('Remove reports a removal', (tester) async {
      final changes = await pump(
        tester,
        currentUrl: '/api/v1/uploads/patients/p/a.jpg',
      );
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();

      expect(changes.single.remove, isTrue);
    });

    testWidgets('backing out of the picker changes nothing', (tester) async {
      chosen = null;
      final changes = await pump(tester);
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      expect(changes, isEmpty);
    });

    testWidgets('a picker that fails says so instead of doing nothing', (
      tester,
    ) async {
      final changes = await pump(tester, picker: _ThrowingPicker());
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();

      expect(changes, isEmpty);
      expect(find.text("Couldn't open that photo. Try another one."), findsOneWidget);
    });

    testWidgets('a pending photo says it is not saved yet', (tester) async {
      await pump(tester, draft: ProfilePhotoDraft(picked: _photo()));

      expect(find.text('New photo. It is saved when you tap Save.'), findsOneWidget);
    });

    testWidgets('and a pending removal says so too', (tester) async {
      await pump(
        tester,
        currentUrl: '/api/v1/x.jpg',
        draft: ProfilePhotoDraft.untouched.withRemoval,
      );

      expect(
        find.text('Photo will be removed when you tap Save.'),
        findsOneWidget,
      );
    });

    testWidgets('reads in Nepali', (tester) async {
      final changes = <ProfilePhotoDraft>[];
      await pumpLocalized(
        tester,
        Scaffold(
          body: ProfilePhotoField(
            initials: 'AR',
            draft: ProfilePhotoDraft.untouched,
            onChanged: changes.add,
          ),
        ),
        locale: const Locale('ne'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(find.text('Take a photo'), findsNothing);
      expect(find.text('फोटो खिच्नुहोस्'), findsOneWidget);
    });
  });
}

class _FakePicker implements PhotoPicker {
  _FakePicker(this.photo);
  final PickedPhoto? photo;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async => photo;
}

class _ThrowingPicker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick(PhotoSource source) async =>
      throw StateError('no camera');
}
