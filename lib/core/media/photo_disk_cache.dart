import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Profile photos kept on disk, so each one is downloaded once, not once per
/// launch.
///
/// The server gives every photo a random filename and deletes the old one on
/// replacement, so a given URL always means the same bytes. That is what makes
/// this a plain write-once store with no invalidation: a changed photo has a
/// new name and so a new entry, and the stale one is simply never asked for
/// again and ages out.
///
/// Only files named like that are cached. Anything else -- a URL whose
/// contents might change under it -- is left to memory, because "never
/// changes" is a promise the server makes for `photo-*` and `thumb-*` and for
/// nothing else.
///
/// Held in the OS's cache directory, which the system may clear: losing it
/// costs a re-download, never data.
class PhotoDiskCache {
  PhotoDiskCache({
    Future<Directory> Function()? directory,
    this.maxBytes = 50 * 1024 * 1024,
    this.enabled = !kIsWeb,
  }) : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;

  /// A soft ceiling. Past it, the least recently used files are deleted.
  final int maxBytes;

  /// False on the web, which has no filesystem to put it on.
  final bool enabled;

  static Future<Directory> _defaultDirectory() async {
    final base = await getTemporaryDirectory();
    return Directory('${base.path}/profile_photos');
  }

  static final _immutableName = RegExp(r'^(photo|thumb)-[0-9a-f]+\.[A-Za-z0-9]+$');

  /// The file a URL is stored under, or null when it should not be cached.
  ///
  /// Owner kind, owner id and filename, which together are unique, joined into
  /// one flat name. The query string is ignored: the server appends the
  /// original filename and size there, which say nothing about the content.
  static String? keyFor(String url) {
    final segments = Uri.tryParse(url.trim())?.pathSegments;
    if (segments == null || segments.length < 3) return null;
    final file = segments.last;
    if (!_immutableName.hasMatch(file)) return null;
    final key = segments.sublist(segments.length - 3).join('_');
    return key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  Future<File?> _file(String url) async {
    final key = keyFor(url);
    if (!enabled || key == null) return null;
    final dir = await _directory();
    return File('${dir.path}/$key');
  }

  Future<Uint8List?> read(String url) async {
    try {
      final file = await _file(url);
      if (file == null || !await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      // Reading is what keeps a photo from being evicted.
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return bytes;
    } catch (_) {
      // A cache that cannot be read is a cache miss, never an error.
      return null;
    }
  }

  int _writes = 0;

  Future<void> write(String url, Uint8List bytes) async {
    try {
      final file = await _file(url);
      if (file == null || bytes.isEmpty) return;
      await file.parent.create(recursive: true);
      // Written beside and renamed over, so a read never sees half a file.
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);

      // Checking the whole directory on every write would cost more than the
      // photos do, so it is done on the first one and then every twenty-fifth.
      if (_writes++ % 25 == 0) await prune();
    } catch (_) {}
  }

  /// Deletes the least recently used files until the total is under
  /// [maxBytes].
  Future<void> prune() async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) return;
      final entries = <({File file, int size, DateTime modified})>[];
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (entity.path.endsWith('.part')) continue;
        final stat = await entity.stat();
        entries.add((file: entity, size: stat.size, modified: stat.modified));
        total += stat.size;
      }
      if (total <= maxBytes) return;
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      for (final e in entries) {
        if (total <= maxBytes) break;
        await e.file.delete();
        total -= e.size;
      }
    } catch (_) {}
  }
}

final photoDiskCacheProvider = Provider<PhotoDiskCache>(
  (ref) => PhotoDiskCache(),
);
