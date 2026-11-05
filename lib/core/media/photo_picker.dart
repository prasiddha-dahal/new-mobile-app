import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Where a photo comes from.
enum PhotoSource { camera, gallery }

/// A photo chosen on the device, held in memory until it is saved.
///
/// Bytes rather than a file path: a path is meaningless on web, and the upload
/// is multipart from memory either way. The photo has already been scaled down
/// by the picker, so this is a few hundred KB, not a 12 MP original.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.filename});

  final Uint8List bytes;

  /// Always ends in an extension the server accepts -- it checks the name, not
  /// the content type, and rejects anything outside jpg/jpeg/png/gif/webp.
  final String filename;
}

/// The seam between the screens and the platform's image picker, so a test can
/// hand back a photo without a camera.
abstract class PhotoPicker {
  /// Null when the person backs out without choosing.
  Future<PickedPhoto?> pick(PhotoSource source);
}

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// The API takes up to 10 MB, but a profile photo is shown at 64px. Scaling
  /// on the device keeps the upload quick on a slow connection, and strips the
  /// phone camera's 4000px original down to something that fits.
  static const _maxEdge = 1080.0;
  static const _quality = 85;

  static const allowedExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedPhoto(
      bytes: bytes,
      filename: uploadFilename(file.name, mimeType: file.mimeType),
    );
  }

  /// A name the server will accept.
  ///
  /// Android hands back whatever the content provider calls the file, and a
  /// photo from a cloud gallery can arrive with no extension at all -- which
  /// the upload endpoint rejects as "only image files are allowed" even though
  /// it is one. Falls back to the MIME type, then to jpg, which is what the
  /// picker re-encodes to when it scales.
  static String uploadFilename(String name, {String? mimeType}) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    if (allowedExtensions.contains(ext)) return name;

    final fromMime = switch (mimeType) {
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final base = dot < 0 ? name : name.substring(0, dot);
    return '${base.isEmpty ? 'photo' : base}.$fromMime';
  }
}
