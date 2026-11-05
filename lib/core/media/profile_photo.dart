import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../config/app_config.dart';
import '../error/failures.dart';
import '../network/error_mapper.dart';
import '../providers/core_providers.dart';
import 'photo_disk_cache.dart';
import 'photo_picker.dart';

/// Whose photo it is. The two roles keep theirs in different places on the
/// server -- a patient's on the patient profile, a therapist's first among the
/// therapist's media -- behind two endpoints that take the same shape.
enum PhotoOwner {
  patient('patients'),
  therapist('therapists');

  const PhotoOwner(this.pathSegment);
  final String pathSegment;
}

/// What the person has asked for on an edit form, not yet sent.
///
/// Held on the form and committed by Save, the way every other field is, so
/// backing out of the screen discards a photo exactly as it discards a name.
/// Uploading the moment a photo was picked would leave a changed avatar behind
/// a screen the person believed they had cancelled.
class ProfilePhotoDraft {
  const ProfilePhotoDraft({this.picked, this.remove = false});

  final PickedPhoto? picked;

  /// Delete the current photo. Meaningless alongside [picked], which replaces
  /// it, so picking clears this.
  final bool remove;

  static const untouched = ProfilePhotoDraft();

  bool get changed => picked != null || remove;

  ProfilePhotoDraft withPicked(PickedPhoto photo) =>
      ProfilePhotoDraft(picked: photo);

  ProfilePhotoDraft get withRemoval => const ProfilePhotoDraft(remove: true);
}

/// `POST|DELETE /uploads/{patients|therapists}/{id}/photo`.
///
/// Both endpoints take either the profile's own id or the user id, so callers
/// pass the signed-in user's id and need not have fetched a profile first.
class ProfilePhotoRepository {
  const ProfilePhotoRepository(this._dio);

  final Dio _dio;

  String _path(PhotoOwner owner, String ownerId) =>
      '/uploads/${owner.pathSegment}/$ownerId/photo';

  /// Uploads [photo], replacing any current one. Returns the new photo's
  /// server-relative URL.
  Future<AppResult<String>> upload({
    required PhotoOwner owner,
    required String ownerId,
    required PickedPhoto photo,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _path(owner, ownerId),
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(photo.bytes, filename: photo.filename),
        }),
      );
      final url = response.data?['url'] as String?;
      if (url == null || url.isEmpty) {
        return const Left(UnknownFailure('The server did not return a photo.'));
      }
      return Right(url);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<AppResult<void>> remove({
    required PhotoOwner owner,
    required String ownerId,
  }) async {
    try {
      await _dio.delete<void>(_path(owner, ownerId));
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}

final profilePhotoRepositoryProvider = Provider<ProfilePhotoRepository>(
  (ref) => ProfilePhotoRepository(ref.watch(dioProvider)),
);

/// Commits a [ProfilePhotoDraft]. Returns true if it changed something, so the
/// caller knows whether to refresh whatever shows the photo.
Future<AppResult<bool>> commitProfilePhoto(
  ProfilePhotoRepository repo, {
  required PhotoOwner owner,
  required String ownerId,
  required ProfilePhotoDraft draft,
}) async {
  final picked = draft.picked;
  if (picked != null) {
    final result = await repo.upload(
      owner: owner,
      ownerId: ownerId,
      photo: picked,
    );
    return result.map((_) => true);
  }
  if (draft.remove) {
    final result = await repo.remove(owner: owner, ownerId: ownerId);
    return result.map((_) => true);
  }
  return const Right(false);
}

/// How many photo downloads may be in flight at once.
///
/// A list builds a card per therapist, each asking for its own photo, so
/// twenty cards scrolling into view would open twenty connections at once --
/// on a mobile connection that is slower for every one of them, and it starves
/// the list's own requests. A handful at a time finish sooner overall.
class FetchGate {
  FetchGate(this.limit);

  final int limit;
  int _running = 0;
  final _waiting = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() task) async {
    if (_running >= limit) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _running++;
    try {
      return await task();
    } finally {
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeAt(0).complete();
    }
  }
}

final photoFetchGateProvider = Provider<FetchGate>((ref) => FetchGate(6));

/// Which decoded-byte entries stay in memory once nothing is watching them.
///
/// A list scrolled away and back should not refetch or re-read its photos, but
/// the app should not hold every photo the person has ever scrolled past. So
/// the most recent [capacity] stay, and the oldest is let go as a new one
/// arrives. Counted rather than timed: a timer is something to leak into every
/// test and to wake the app for, and a count is what actually bounds memory.
class PhotoMemoryHold {
  PhotoMemoryHold({this.capacity = 48});

  final int capacity;
  final _links = <String, KeepAliveLink>{};

  void hold(String key, KeepAliveLink link) {
    _links.remove(key)?.close();
    _links[key] = link;
    while (_links.length > capacity) {
      _links.remove(_links.keys.first)!.close();
    }
  }
}

final photoMemoryHoldProvider = Provider<PhotoMemoryHold>(
  (ref) => PhotoMemoryHold(),
);

/// The bytes behind a photo URL.
///
/// Uploaded files are served behind the bearer token, which `Image.network`
/// cannot send, so the bytes are fetched through the app's own Dio. They come
/// from, in order: this provider's memory, the disk cache, the network -- and a
/// network fetch is written to disk, so it happens once per photo, not once per
/// launch.
///
/// The most recent few dozen stay in memory after their widget goes away (see
/// [PhotoMemoryHold]), which outlasts a scroll away and back. Resolves to null on any failure rather than throwing: a
/// photo that cannot be loaded is not worth an error screen, and the initials
/// stand in.
final profilePhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, url) async {
      ref.read(photoMemoryHoldProvider).hold(url, ref.keepAlive());

      final disk = ref.read(photoDiskCacheProvider);
      final cached = await disk.read(url);
      if (cached != null) return cached;

      try {
        final response = await ref
            .read(photoFetchGateProvider)
            .run(
              () => ref
                  .read(dioProvider)
                  .get<List<int>>(
                    AppConfig.resolveMediaUrl(url),
                    options: Options(responseType: ResponseType.bytes),
                  ),
            );
        final data = response.data;
        if (data == null || data.isEmpty) return null;
        final bytes = Uint8List.fromList(data);
        unawaited(disk.write(url, bytes));
        return bytes;
      } catch (_) {
        return null;
      }
    });
