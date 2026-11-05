import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/media/photo_picker.dart';
import 'package:sahayatri_care_connect/core/media/profile_photo.dart';
import 'package:sahayatri_care_connect/core/network/providers.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/patient/data/datasources/patient_api.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/care_models.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/edit_profile_screen.dart';

import '../../l10n_harness.dart';

/// Edit profile wrote to one endpoint and drew fields for two.
///
/// `PUT /auth/me` takes name, city, phone and specialty — nothing else. Home
/// address, medical history and primary concern live on
/// `PUT /patients/me/profile`, which the app never called, so all three were
/// rendered as disabled boxes marked "coming soon" while the endpoint behind
/// them had existed for months. From the patient's side the profile form
/// simply did not work: only two fields accepted input.
///
/// Date of birth and gender are the genuine exception. The API removed both
/// from `PatientProfileUpdate` when they became admin-only, so a client that
/// sends either gets a 422 — they have to stay read-only, and these tests pin
/// that they stay read-only *with their real value shown*, which is the part a
/// future "let's enable the rest of them" change would get wrong.
class _FakeApi implements PatientApi {
  _FakeApi({this.profile, this.missing = false, this.log});

  final PatientProfileDto? profile;

  /// Shared with the photo fake so a test can read the order of the two saves.
  final List<String>? log;

  /// A patient who has never saved a care record: `GET` 404s.
  final bool missing;

  PatientProfileUpdateDto? sent;

  @override
  Future<PatientProfileDto> getMyProfile() async {
    if (missing) {
      final options = RequestOptions(path: '/patients/me/profile');
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 404),
      );
    }
    return profile!;
  }

  @override
  Future<PatientProfileDto> updateMyProfile(PatientProfileUpdateDto body) async {
    sent = body;
    log?.add('care:save');
    return profile ??
        const PatientProfileDto(name: 'Asha', phone: '', city: 'Lalitpur');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _FakeAuthRepository implements AuthRepository {
  ({String? name, String? city, String? phone})? sent;

  @override
  Future<AppResult<User>> updateProfile({
    String? name,
    String? city,
    String? phone,
    String? specialty,
  }) async {
    sent = (name: name, city: city, phone: phone);
    return Right(
      User(
        id: 'u1',
        name: name ?? 'Asha',
        email: 'asha@test.com',
        role: 'PATIENT',
        city: city,
        phone: phone,
        status: 'APPROVED',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Records what the screen asked the photo endpoint to do, and in what order
/// relative to the care save -- the order is the point.
class _FakePhotoRepository implements ProfilePhotoRepository {
  _FakePhotoRepository(this.log, {this.failWith});

  final List<String> log;
  final Failure? failWith;

  PhotoOwner? owner;
  String? ownerId;
  PickedPhoto? uploaded;

  @override
  Future<AppResult<String>> upload({
    required PhotoOwner owner,
    required String ownerId,
    required PickedPhoto photo,
  }) async {
    log.add('photo:upload');
    this.owner = owner;
    this.ownerId = ownerId;
    uploaded = photo;
    if (failWith != null) return Left(failWith!);
    return const Right('/api/v1/uploads/patients/p1/photo-new.jpg');
  }

  @override
  Future<AppResult<void>> remove({
    required PhotoOwner owner,
    required String ownerId,
  }) async {
    log.add('photo:remove');
    this.owner = owner;
    this.ownerId = ownerId;
    return const Right(null);
  }
}

class _GalleryPicker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick(PhotoSource source) async => PickedPhoto(
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
      '60e6kgAAAABJRU5ErkJggg==',
    ),
    filename: 'me.png',
  );
}

const _stored = PatientProfileDto(
  name: 'Asha Rai',
  phone: '9800000000',
  city: 'Lalitpur',
  address: 'Jhamsikhel, house 12',
  history: 'ACL repair 2023',
  dob: '1994-04-02',
  gender: 'Female',
  condition: 'Lower back pain',
);

void main() {
  const user = User(
    id: 'u1',
    name: 'Asha Rai',
    email: 'asha@test.com',
    role: 'PATIENT',
    city: 'Lalitpur',
    phone: '9800000000',
    status: 'APPROVED',
  );

  Future<(_FakeApi, _FakeAuthRepository)> pumpScreen(
    WidgetTester tester, {
    PatientProfileDto? profile = _stored,
    bool missing = false,
    List<String>? log,
    _FakePhotoRepository? photos,
  }) async {
    final api = _FakeApi(profile: profile, missing: missing, log: log);
    final auth = _FakeAuthRepository();
    // A router has to be in scope: a successful save closes the screen, and
    // `context.canPop()` asserts rather than returning false when there is
    // none. Two routes are enough for both branches of `_close`.
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        GoRoute(
          path: '/patient/account',
          builder: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpLocalized(
      tester,
      InheritedGoRouter(goRouter: router, child: const EditProfileScreen()),
      size: const Size(390, 3000),
      overrides: [
        patientApiProvider.overrideWithValue(api),
        authRepositoryProvider.overrideWithValue(auth),
        // Set before the first frame, as it is in the app: the screen seeds
        // its name, phone and city controllers in initState.
        authProvider.overrideWith((_) => user),
        photoPickerProvider.overrideWithValue(_GalleryPicker()),
        if (photos != null)
          profilePhotoRepositoryProvider.overrideWithValue(photos),
      ],
    );
    await tester.pumpAndSettle();
    return (api, auth);
  }

  /// The input under [label], or null when that label belongs to a read-only
  /// box. Found by label rather than by index so adding a field above does not
  /// silently retarget these assertions.
  Finder? inputFor(WidgetTester tester, String label) {
    final group = find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first;
    final input = find.descendant(of: group, matching: find.byType(TextFormField));
    return input.evaluate().isEmpty ? null : input.first;
  }

  String? fieldText(WidgetTester tester, String label) {
    final input = inputFor(tester, label);
    if (input == null) return null;
    return tester.widget<TextFormField>(input).controller?.text;
  }

  /// Taps Save and settles.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
  }

  testWidgets('the care fields are editable and prefilled from the profile', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      fieldText(tester, 'HOME ADDRESS'),
      'Jhamsikhel, house 12',
      reason: 'home address was a disabled box; it has an endpoint and must '
          'take input',
    );
    expect(fieldText(tester, 'PRIMARY CONCERN'), 'Lower back pain');
    expect(fieldText(tester, 'MEDICAL HISTORY'), 'ACL repair 2023');
  });

  testWidgets('city is its own field, separate from home address', (
    tester,
  ) async {
    await pumpScreen(tester);

    // These used to be the same control: the box labelled "home address" wrote
    // to `city`, so a patient who typed a street address broke their own
    // therapist matching without being told.
    expect(fieldText(tester, 'CITY / AREA'), 'Lalitpur');
    expect(fieldText(tester, 'HOME ADDRESS'), isNot('Lalitpur'));
  });

  testWidgets('date of birth and gender show their value but take no input', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('1994-04-02'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(
      fieldText(tester, 'DATE OF BIRTH'),
      isNull,
      reason: 'the API rejects dob from a patient, so an input here would '
          'collect a value only to 422 on save',
    );
    expect(fieldText(tester, 'GENDER'), isNull);
  });

  testWidgets('and say why, rather than promising a feature', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('set at signup'), findsWidgets);
    expect(
      find.textContaining('coming soon'),
      findsNothing,
      reason: 'nothing on this screen is pending any more',
    );
  });

  testWidgets('gender falls back to a placeholder when it is the default', (
    tester,
  ) async {
    // 'Any' is the column default — it means the question was never asked, not
    // that the patient chose it.
    await pumpScreen(
      tester,
      profile: const PatientProfileDto(
        name: 'Asha Rai',
        phone: '9800000000',
        city: 'Lalitpur',
        gender: 'Any',
      ),
    );

    expect(find.text('Any'), findsNothing);
    expect(find.text('Not recorded'), findsWidgets);
  });

  testWidgets('saving sends the care fields to the profile endpoint', (
    tester,
  ) async {
    final (api, auth) = await pumpScreen(tester);

    await tester.enterText(inputFor(tester, 'HOME ADDRESS')!, 'Sanepa, house 7');
    await tapSave(tester);

    expect(api.sent, isNotNull, reason: 'the profile endpoint must be called');
    expect(api.sent!.address, 'Sanepa, house 7');
    expect(api.sent!.condition, 'Lower back pain');
    expect(api.sent!.history, 'ACL repair 2023');

    // The account row still has to be written: the header, the greeting and
    // the therapist search all read name, city and phone from `User`, not from
    // the care record.
    expect(auth.sent, isNotNull);
    expect(auth.sent!.city, 'Lalitpur');
  });

  testWidgets('a patient with no care record yet gets empty, usable fields', (
    tester,
  ) async {
    // `GET /patients/me/profile` 404s until the first save upserts a row. That
    // is not an error to render — the form has to open and work.
    final (api, _) = await pumpScreen(tester, missing: true);

    expect(fieldText(tester, 'HOME ADDRESS'), '');
    expect(
      fieldText(tester, 'CITY / AREA'),
      'Lalitpur',
      reason: 'city falls back to the account row, which always has one',
    );

    await tester.enterText(inputFor(tester, 'HOME ADDRESS')!, 'Sanepa');
    await tapSave(tester);

    expect(api.sent!.address, 'Sanepa');
  });

  group('the profile photo', () {
    Future<void> pickFromGallery(WidgetTester tester) async {
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
    }

    testWidgets('Change photo opens a picker, not a "not available" toast', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();

      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.textContaining('not available'), findsNothing);
    });

    testWidgets('a picked photo is uploaded on Save, after the care record', (
      tester,
    ) async {
      final log = <String>[];
      final photos = _FakePhotoRepository(log);
      await pumpScreen(tester, log: log, photos: photos);

      await pickFromGallery(tester);
      expect(
        photos.uploaded,
        isNull,
        reason: 'nothing is sent until Save, so backing out discards it',
      );
      await tapSave(tester);

      expect(photos.uploaded!.filename, 'me.png');
      expect(photos.owner, PhotoOwner.patient);
      expect(photos.ownerId, 'u1');
      expect(
        log,
        ['care:save', 'photo:upload'],
        reason: 'a patient with no care record has no profile row to attach a '
            'photo to until the care save creates it',
      );
    });

    testWidgets('no photo change means no photo request', (tester) async {
      final log = <String>[];
      final photos = _FakePhotoRepository(log);
      await pumpScreen(tester, log: log, photos: photos);

      await tester.enterText(inputFor(tester, 'HOME ADDRESS')!, 'Sanepa');
      await tapSave(tester);

      expect(log, ['care:save']);
    });

    testWidgets('Remove photo deletes it on Save', (tester) async {
      final log = <String>[];
      final photos = _FakePhotoRepository(log);
      await pumpScreen(
        tester,
        log: log,
        photos: photos,
        profile: const PatientProfileDto(
          name: 'Asha Rai',
          phone: '9800000000',
          city: 'Lalitpur',
          photo: '/api/v1/uploads/patients/p1/photo-old.jpg',
        ),
      );

      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      expect(log, isEmpty, reason: 'not until Save');
      await tapSave(tester);

      expect(log, ['care:save', 'photo:remove']);
    });

    testWidgets('a failed upload says the fields saved, and stays open', (
      tester,
    ) async {
      final log = <String>[];
      final photos = _FakePhotoRepository(
        log,
        failWith: const UnknownFailure('File exceeds maximum size of 10MB'),
      );
      final (api, _) = await pumpScreen(tester, log: log, photos: photos);

      await pickFromGallery(tester);
      await tapSave(tester);

      expect(api.sent, isNotNull, reason: 'the fields did save');
      expect(
        find.textContaining('Your profile was saved, but the photo was not'),
        findsOneWidget,
      );
      expect(find.textContaining('10MB'), findsOneWidget);
      expect(
        find.text('Save changes'),
        findsOneWidget,
        reason: 'still open, so Save can retry the photo',
      );

      // And the retry sends it again.
      await tapSave(tester);
      expect(
        log.where((e) => e == 'photo:upload'),
        hasLength(2),
      );
    });
  });

  group('the mobile number', () {
    testWidgets('fewer than ten digits is refused with a reason', (tester) async {
      final (api, auth) = await pumpScreen(tester);

      await tester.enterText(inputFor(tester, 'MOBILE NUMBER')!, '98012345');
      await tapSave(tester);

      expect(
        find.text('That number is too short — a mobile number has exactly 10 digits.'),
        findsOneWidget,
      );
      expect(api.sent, isNull, reason: 'an invalid number must not be saved');
      expect(auth.sent, isNull);
    });

    testWidgets('more than ten digits is refused with a different reason', (
      tester,
    ) async {
      final (api, _) = await pumpScreen(tester);

      await tester.enterText(inputFor(tester, 'MOBILE NUMBER')!, '980123456789');
      await tapSave(tester);

      expect(
        find.text('That number is too long — a mobile number has exactly 10 digits.'),
        findsOneWidget,
      );
      expect(api.sent, isNull);
    });

    testWidgets('typing keeps digits only', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(inputFor(tester, 'MOBILE NUMBER')!, '98-01 23abc');
      await tester.pump();

      expect(fieldText(tester, 'MOBILE NUMBER'), '980123');
    });

    testWidgets('ten digits saves', (tester) async {
      final (_, auth) = await pumpScreen(tester);

      await tester.enterText(inputFor(tester, 'MOBILE NUMBER')!, '9841234567');
      await tapSave(tester);

      expect(auth.sent!.phone, '9841234567');
    });
  });
}
