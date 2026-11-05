import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/media/photo_disk_cache.dart';
import 'package:sahayatri_care_connect/core/media/profile_photo.dart';
import 'package:sahayatri_care_connect/core/providers/core_providers.dart';
import 'package:sahayatri_care_connect/core/widgets/profile_avatar.dart';

import '../l10n_harness.dart';

/// A photo is shown at 40-64dp on every card, and a list builds twenty cards.
/// These pin the three things that keep that cheap: the thumbnail is what a
/// small avatar fetches, a photo is downloaded once rather than once per
/// launch, and only a few downloads run at a time.
const _thumb = '/api/v1/uploads/therapists/t1/thumb-ab12.jpg?name=a&size=9';
const _photo = '/api/v1/uploads/therapists/t1/photo-ab12.jpg?name=a&size=9';

/// A real 1x1 PNG, so the avatar can decode it.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, //
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x44,
  0x41, 0x54, 0x78, 0xda, 0x63, 0xfc, 0xcf, 0xc0, 0xf0, 0x1f, 0x00, 0x05, 0x85,
  0x02, 0x00, 0x1c, 0x6d, 0x14, 0xd3, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
  0x44, 0xae, 0x42, 0x60, 0x82,
]);

class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, this.delay = Duration.zero});

  final int status;
  final Duration delay;
  final requests = <String>[];
  int running = 0;
  int peak = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri.toString());
    running++;
    if (running > peak) peak = running;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    running--;
    return ResponseBody.fromBytes(_png, status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('photo_cache_test'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  PhotoDiskCache cache({int maxBytes = 50 * 1024 * 1024, bool enabled = true}) =>
      PhotoDiskCache(directory: () async => dir, maxBytes: maxBytes, enabled: enabled);

  group('what gets cached', () {
    test('a photo and a thumbnail do, whatever their query string', () {
      expect(
        PhotoDiskCache.keyFor(_thumb),
        PhotoDiskCache.keyFor('/api/v1/uploads/therapists/t1/thumb-ab12.jpg?x=1'),
        reason: 'the query holds the original filename and size, not the content',
      );
      expect(PhotoDiskCache.keyFor(_thumb), isNotNull);
      expect(PhotoDiskCache.keyFor(_photo), isNot(PhotoDiskCache.keyFor(_thumb)));
    });

    test('two people with one filename do not collide', () {
      expect(
        PhotoDiskCache.keyFor('/api/v1/uploads/therapists/t1/photo-ab12.jpg'),
        isNot(PhotoDiskCache.keyFor('/api/v1/uploads/patients/t1/photo-ab12.jpg')),
      );
    });

    test('anything the server does not promise is immutable does not', () {
      expect(PhotoDiskCache.keyFor('/api/v1/uploads/therapists/t1/licence.pdf'), isNull);
      expect(PhotoDiskCache.keyFor('/avatar.jpg'), isNull);
      expect(PhotoDiskCache.keyFor('https://cdn.example.com/me.png'), isNull);
      expect(PhotoDiskCache.keyFor(''), isNull);
    });

    test('the key is a safe filename', () {
      final key = PhotoDiskCache.keyFor('/api/v1/uploads/therapists/a b%2Fc/photo-ab12.jpg')!;
      expect(key, isNot(contains('/')));
      expect(key, isNot(contains(' ')));
    });
  });

  group('the disk cache', () {
    test('what was written is read back', () async {
      final c = cache();
      await c.write(_thumb, _png);

      expect(await c.read(_thumb), _png);
    });

    test('a different query string finds the same file', () async {
      final c = cache();
      await c.write(_thumb, _png);

      expect(await c.read('/api/v1/uploads/therapists/t1/thumb-ab12.jpg'), _png);
    });

    test('a miss is null, not an error', () async {
      expect(await cache().read(_thumb), isNull);
    });

    test('an uncacheable URL is never written', () async {
      final c = cache();
      await c.write('/api/v1/uploads/therapists/t1/licence.pdf', _png);

      expect(dir.listSync(), isEmpty);
    });

    test('an empty body is not cached', () async {
      final c = cache();
      await c.write(_thumb, Uint8List(0));

      expect(await c.read(_thumb), isNull);
    });

    test('disabled does nothing at all', () async {
      final c = cache(enabled: false);
      await c.write(_thumb, _png);

      expect(await c.read(_thumb), isNull);
      expect(dir.listSync(), isEmpty);
    });

    test('a folder that cannot be made is a miss, not a crash', () async {
      final c = PhotoDiskCache(directory: () async => throw const FileSystemException('no'));

      await c.write(_thumb, _png);
      expect(await c.read(_thumb), isNull);
    });

    test('leaves no half-written file behind', () async {
      final c = cache();
      await c.write(_thumb, _png);

      expect(dir.listSync().whereType<File>().where((f) => f.path.endsWith('.part')), isEmpty);
    });

    test('over its limit, the least recently used go first', () async {
      final c = cache(maxBytes: 250);
      const old = '/api/v1/uploads/therapists/t1/thumb-0001.jpg';
      const mid = '/api/v1/uploads/therapists/t1/thumb-0002.jpg';
      const fresh = '/api/v1/uploads/therapists/t1/thumb-0003.jpg';
      final block = Uint8List(100);
      for (final u in [old, mid, fresh]) {
        await c.write(u, block);
      }
      // Age them explicitly, then use `old` so it becomes the newest.
      final files = {for (final f in dir.listSync().whereType<File>()) f.uri.pathSegments.last: f};
      files['therapists_t1_thumb-0001.jpg']!.setLastModifiedSync(DateTime(2024, 1, 1));
      files['therapists_t1_thumb-0002.jpg']!.setLastModifiedSync(DateTime(2024, 1, 2));
      files['therapists_t1_thumb-0003.jpg']!.setLastModifiedSync(DateTime(2024, 1, 3));
      await c.read(old);

      await c.prune();

      expect(await c.read(mid), isNull, reason: 'the stalest was evicted');
      expect(await c.read(old), isNotNull, reason: 'reading keeps it alive');
      expect(await c.read(fresh), isNotNull);
    });
  });

  group('the bytes provider', () {
    ProviderContainer containerWith(_Adapter adapter, PhotoDiskCache disk) {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          photoDiskCacheProvider.overrideWithValue(disk),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('downloads a photo once, however often it is asked for', () async {
      final adapter = _Adapter();
      final container = containerWith(adapter, cache());

      final first = await container.read(profilePhotoBytesProvider(_thumb).future);
      final second = await container.read(profilePhotoBytesProvider(_thumb).future);

      expect(first, _png);
      expect(second, _png);
      expect(adapter.requests, hasLength(1));
    });

    test('and not again on the next launch', () async {
      final disk = cache();
      final firstRun = _Adapter();
      await containerWith(firstRun, disk).read(profilePhotoBytesProvider(_thumb).future);
      // The provider does not wait for the disk write (a slow disk must not
      // hold up the picture), so wait for the file itself rather than a guessed
      // number of milliseconds, which is too few when the suite runs in
      // parallel.
      for (var i = 0; i < 200 && await disk.read(_thumb) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(await disk.read(_thumb), isNotNull, reason: 'it was written to disk');

      // A new container is a new launch: nothing in memory.
      final secondRun = _Adapter();
      final bytes = await containerWith(secondRun, disk)
          .read(profilePhotoBytesProvider(_thumb).future);

      expect(bytes, _png);
      expect(secondRun.requests, isEmpty, reason: 'it came from disk');
    });

    test('asks the host the app is configured for', () async {
      final adapter = _Adapter();
      await containerWith(adapter, cache()).read(profilePhotoBytesProvider(_thumb).future);

      expect(adapter.requests.single, contains('/api/v1/uploads/therapists/t1/thumb-ab12.jpg'));
    });

    test('a failed download is null and is not cached', () async {
      final disk = cache();
      final container = containerWith(_Adapter(status: 404), disk);

      final bytes = await container.read(profilePhotoBytesProvider(_thumb).future);

      expect(bytes, isNull);
      expect(await disk.read(_thumb), isNull);
    });
  });

  group('the download gate', () {
    test('lets only its limit run at once', () async {
      final gate = FetchGate(3);
      var running = 0;
      var peak = 0;

      await Future.wait([
        for (var i = 0; i < 10; i++)
          gate.run(() async {
            running++;
            if (running > peak) peak = running;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            running--;
          }),
      ]);

      expect(peak, 3);
    });

    test('runs everything that is queued', () async {
      final gate = FetchGate(2);
      final done = <int>[];

      await Future.wait([
        for (var i = 0; i < 7; i++) gate.run(() async => done.add(i)),
      ]);

      expect(done..sort(), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('a task that throws still frees its place', () async {
      final gate = FetchGate(1);

      await expectLater(gate.run<void>(() async => throw StateError('x')), throwsStateError);
      expect(await gate.run(() async => 'next'), 'next');
    });

    test('the provider uses it, so a screen of avatars is a few requests at a time', () async {
      final adapter = _Adapter(delay: const Duration(milliseconds: 10));
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          photoDiskCacheProvider.overrideWithValue(cache(enabled: false)),
        ],
      );
      addTearDown(container.dispose);

      await Future.wait([
        for (var i = 0; i < 20; i++)
          container.read(
            profilePhotoBytesProvider('/api/v1/uploads/therapists/t$i/thumb-ab12.jpg').future,
          ),
      ]);

      expect(adapter.requests, hasLength(20));
      expect(adapter.peak, lessThanOrEqualTo(6));
    });
  });

  group('memory', () {
    test('holds the most recent photos and lets the oldest go', () {
      final hold = PhotoMemoryHold(capacity: 2);
      final a = _Link(), b = _Link(), c = _Link();

      hold.hold('a', a);
      hold.hold('b', b);
      expect(a.closed || b.closed, isFalse);

      hold.hold('c', c);

      expect(a.closed, isTrue, reason: 'the oldest was let go');
      expect(b.closed, isFalse);
      expect(c.closed, isFalse);
    });

    test('holding the same photo again replaces its link and keeps the count', () {
      final hold = PhotoMemoryHold(capacity: 2);
      final first = _Link(), second = _Link(), other = _Link();

      hold.hold('a', first);
      hold.hold('a', second);
      hold.hold('b', other);

      expect(first.closed, isTrue, reason: 'the superseded link is released');
      expect(second.closed, isFalse);
      expect(other.closed, isFalse);
    });
  });

  group('which link an avatar fetches', () {
    String? pick(double size, {String? photo, String? thumb}) =>
        ProfileAvatar.chooseUrl(size: size, photoUrl: photo, thumbUrl: thumb);

    test('a small avatar takes the thumbnail', () {
      expect(pick(40, photo: _photo, thumb: _thumb), _thumb);
      expect(pick(96, photo: _photo, thumb: _thumb), _thumb);
    });

    test('a large one takes the full photo', () {
      expect(pick(120, photo: _photo, thumb: _thumb), _photo);
    });

    test('whichever exists, when only one does', () {
      expect(pick(40, photo: _photo), _photo, reason: 'an older response');
      expect(pick(120, thumb: _thumb), _thumb);
    });

    test('none at all, or only blanks, is no photo', () {
      expect(pick(40), isNull);
      expect(pick(40, photo: '  ', thumb: ''), isNull);
    });
  });

  group('the avatar widget', () {
    Future<_Adapter> pump(
      WidgetTester tester, {
      String? photo,
      String? thumb,
      double size = 50,
      double dpr = 1.0,
    }) async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = adapter;
      await pumpLocalized(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              // The harness pins the view to 1x, so the density under test is
              // set where the avatar reads it.
              data: MediaQuery.of(context).copyWith(devicePixelRatio: dpr),
              child: Center(
                child: ProfileAvatar(
                  initials: 'AS',
                  photoUrl: photo,
                  thumbUrl: thumb,
                  size: size,
                ),
              ),
            ),
          ),
        ),
        overrides: [
          dioProvider.overrideWithValue(dio),
          photoDiskCacheProvider.overrideWithValue(cache(enabled: false)),
        ],
      );
      await tester.pumpAndSettle();
      return adapter;
    }

    testWidgets('fetches the thumbnail for a card, not the photo', (tester) async {
      final adapter = await pump(tester, photo: _photo, thumb: _thumb);

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single, contains('thumb-ab12'));
      expect(adapter.requests.single, isNot(contains('photo-ab12')));
    });

    testWidgets('shows the initials when there is no photo, and fetches nothing', (
      tester,
    ) async {
      final adapter = await pump(tester);

      expect(find.text('AS'), findsOneWidget);
      expect(adapter.requests, isEmpty);
    });

    testWidgets('draws the photo once it has arrived', (tester) async {
      await pump(tester, thumb: _thumb);

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('AS'), findsNothing);
    });

    testWidgets('decodes at the size it is drawn, not the size it was stored', (
      tester,
    ) async {
      await pump(tester, thumb: _thumb, size: 50, dpr: 3.0);

      final image = tester.widget<Image>(find.byType(Image)).image;
      expect(image, isA<ResizeImage>());
      expect((image as ResizeImage).width, 150, reason: '50dp at 3x');
    });

    testWidgets('a full photo is decoded wider, so a landscape one still fills the circle', (
      tester,
    ) async {
      await pump(tester, photo: _photo, size: 120, dpr: 2.0);

      final image = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect(image.width, 480, reason: 'twice 120dp at 2x');
    });

    testWidgets('falls back to the initials when the fetch fails', (tester) async {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
        ..httpClientAdapter = _Adapter(status: 404);
      await pumpLocalized(
        tester,
        const Scaffold(
          body: Center(
            child: ProfileAvatar(initials: 'AS', thumbUrl: _thumb, size: 50),
          ),
        ),
        overrides: [
          dioProvider.overrideWithValue(dio),
          photoDiskCacheProvider.overrideWithValue(cache(enabled: false)),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('AS'), findsOneWidget);
    });
  });
}

class _Link implements KeepAliveLink {
  bool closed = false;

  @override
  void close() => closed = true;
}
