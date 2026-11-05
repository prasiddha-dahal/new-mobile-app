import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

import '../l10n/l10n.dart';
import '../media/photo_picker.dart';
import '../media/profile_photo.dart';
import '../theme/app_colors.dart';
import 'profile_avatar.dart';
import 'shared_widgets.dart';

/// The avatar and "Change photo" button on an edit-profile form.
///
/// Controlled: the form owns the [ProfilePhotoDraft] and sends it with Save,
/// so a photo behaves like every other field -- backing out discards it.
class ProfilePhotoField extends ConsumerWidget {
  const ProfilePhotoField({
    super.key,
    required this.initials,
    required this.draft,
    required this.onChanged,
    this.currentUrl,
    this.currentThumbUrl,
    this.size = 64,
    this.enabled = true,
  });

  /// The photo the server holds now, if any.
  final String? currentUrl;
  final String? currentThumbUrl;
  final String initials;
  final ProfilePhotoDraft draft;
  final ValueChanged<ProfilePhotoDraft> onChanged;
  final double size;
  final bool enabled;

  bool get _hasPhoto =>
      draft.picked != null ||
      (!draft.remove && (currentUrl ?? '').trim().isNotEmpty);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final picked = draft.picked;

    final Widget avatar;
    if (picked != null) {
      // What was just chosen, shown from memory: it has not been uploaded, so
      // there is nothing on the server to fetch.
      avatar = ClipOval(
        child: Image.memory(
          picked.bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => AppAvatar(initials: initials, size: size),
        ),
      );
    } else if (draft.remove) {
      avatar = AppAvatar(initials: initials, size: size);
    } else {
      avatar = ProfileAvatar(
        initials: initials,
        photoUrl: currentUrl,
        thumbUrl: currentThumbUrl,
        size: size,
      );
    }

    final note = picked != null
        ? l10n.photoPendingNote
        : (draft.remove ? l10n.photoRemovalPendingNote : null);

    return Row(
      children: [
        avatar,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton(
                onPressed: enabled ? () => _openSheet(context, ref) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(l10n.editProfileChangePhoto),
              ),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASTE INTO profile_photo_field.dart
  //
  // Replace the whole `_openSheet` method with the one below. It needs one
  // extra import at the top of that file (adjust the relative path):
  //
  //   import '../theme/app_typography.dart';
  //
  // Nothing else in the file changes: the choices, the picker, the removal and
  // the error snackbar behave exactly as before.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      // The root navigator: the account shells keep their bottom bar above a
      // sheet opened on their own, which hid the last option -- Remove photo,
      // the one that only appears once there is a photo.
      useRootNavigator: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        final text = AppTypography.textTheme;

        /// One row: a soft round icon, then the label.
        Widget option({
          required IconData icon,
          required String label,
          required _PhotoChoice value,
          bool destructive = false,
        }) {
          final color = destructive ? AppColors.danger : AppColors.pine;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: destructive
                    ? AppColors.dangerPale
                    : Color.alphaBlend(
                        AppColors.pinePale.withAlpha(150),
                        Colors.white,
                      ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            title: Text(label),
            // ListTile otherwise draws its title in the theme's own body style.
            titleTextStyle: text.titleSmall!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: destructive ? AppColors.danger : AppColors.ink,
            ),
            onTap: () => Navigator.pop(sheetContext, value),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grab handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    l10n.photoSheetTitle,
                    style: text.titleLarge!.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                option(
                  icon: Icons.photo_camera_outlined,
                  label: l10n.photoTake,
                  value: _PhotoChoice.camera,
                ),
                option(
                  icon: Icons.photo_library_outlined,
                  label: l10n.photoChoose,
                  value: _PhotoChoice.gallery,
                ),
                if (_hasPhoto)
                  option(
                    icon: Icons.delete_outline,
                    label: l10n.photoRemove,
                    value: _PhotoChoice.remove,
                    destructive: true,
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || !context.mounted) return;

    if (choice == _PhotoChoice.remove) {
      onChanged(draft.withRemoval);
      return;
    }

    final source = choice == _PhotoChoice.camera
        ? PhotoSource.camera
        : PhotoSource.gallery;
    try {
      final photo = await ref.read(photoPickerProvider).pick(source);
      if (photo != null) onChanged(draft.withPicked(photo));
    } catch (_) {
      // Permission denied, no camera, a provider that would not open the
      // file. All the same to the person: that photo did not work.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.photoPickFailed)));
    }
  }
}

enum _PhotoChoice { camera, gallery, remove }
