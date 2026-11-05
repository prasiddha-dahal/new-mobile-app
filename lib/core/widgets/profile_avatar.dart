import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/profile_photo.dart';
import '../theme/app_colors.dart';
import 'shared_widgets.dart';

/// A person's avatar: their photo when they have one, their initials when they
/// do not -- or while the photo is still on its way, or cannot be fetched.
///
/// The initials are the fallback for every one of those, which is why there is
/// no spinner: a profile with no photo is the common case, and a spinner there
/// would be a loading state that never ends. A photo that arrives replaces the
/// initials in place.
///
/// Pass both links when the API gave both. The thumbnail is a 256px square, a
/// few kilobytes, and is what every list and card should draw; the full photo
/// is for a profile page. Which is used follows from [size], so a screen does
/// not have to remember to ask for the cheap one.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.thumbUrl,
    this.size = 40,
    this.tint = AppColors.pinePale,
  });

  final String initials;

  /// The full photo, at most 1024px. Server-relative or absolute.
  final String? photoUrl;

  /// The 256px square. Null for a photo uploaded before thumbnails existed --
  /// the server builds one on first request, but only a client that has the
  /// link can ask, so an older response simply falls back to [photoUrl].
  final String? thumbUrl;
  final double size;
  final Color tint;

  /// At or below this, a 256px thumbnail is already more pixels than the
  /// screen has for it (96dp is 288px on a 3x phone).
  static const thumbMaxSize = 96.0;

  /// The link that is worth fetching at [size]: the thumbnail for a small
  /// avatar, the full photo for a large one, and whichever exists if only one
  /// does.
  static String? chooseUrl({
    required double size,
    String? photoUrl,
    String? thumbUrl,
  }) {
    final thumb = (thumbUrl ?? '').trim();
    final photo = (photoUrl ?? '').trim();
    final preferThumb = size <= thumbMaxSize;
    final first = preferThumb ? thumb : photo;
    final second = preferThumb ? photo : thumb;
    if (first.isNotEmpty) return first;
    return second.isEmpty ? null : second;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = AppAvatar(initials: initials, tint: tint, size: size);
    final url = chooseUrl(size: size, photoUrl: photoUrl, thumbUrl: thumbUrl);
    if (url == null) return fallback;

    final bytes = ref.watch(profilePhotoBytesProvider(url)).valueOrNull;
    if (bytes == null) return fallback;

    // Decoded at the size it is drawn, not at the size it was stored: a 1024px
    // photo expands to about 4 MB of bitmap, and a list of twenty is 80 MB of
    // memory for a column of circles. A thumbnail is square, so its width is
    // the whole story; a full photo may be landscape, and cover-fitting it
    // needs the *short* side to reach the target, so it is decoded at twice
    // the width rather than distorted or left blurry.
    final target = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    final isThumb = url == (thumbUrl ?? '').trim();
    final decodeWidth = isThumb ? target : (target * 2).clamp(target, 1024);

    return ClipOval(
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        // Keeps the old frame up while a new photo decodes, instead of
        // flashing empty between the two.
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
