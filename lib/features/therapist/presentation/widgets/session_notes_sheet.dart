import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../patient/domain/entities/session.dart';
import '../providers/therapist_providers.dart';
import '../../../../core/validation/validators.dart';

/// Write-up sheet for a completed session.
///
/// Saves to `PUT /sessions/{id}` as `notes`. File attachments would need
/// `POST /reports`, which is multipart and needs a file picker — see the upload
/// screen for that path.
Future<bool?> showSessionNotesSheet(
  BuildContext context, {
  required Session session,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _SessionNotesSheet(session: session),
  );
}

class _SessionNotesSheet extends ConsumerStatefulWidget {
  const _SessionNotesSheet({required this.session});
  final Session session;

  @override
  ConsumerState<_SessionNotesSheet> createState() => _SessionNotesSheetState();
}

class _SessionNotesSheetState extends ConsumerState<_SessionNotesSheet> {
  late final TextEditingController _notes = TextEditingController(
    text: widget.session.notes ?? '',
  );

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _notes.text.trim();
    // These notes are clinical record and are handed to the next therapist,
    // so a one-word entry is worse than none.
    final notesError = Validators.longText(
      context.l10n,
      context.l10n.fieldRemarks,
      min: 15,
      max: 2000,
    )(
      text,
    );
    if (notesError != null) {
      setState(() => _error = notesError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref
        .read(therapistActionsProvider)
        .saveSessionNotes(sessionId: widget.session.id, notes: text);

    if (!mounted) return;
    setState(() => _busy = false);

    result.match((failure) => setState(() => _error = failure.message), (_) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.remarksSaved)),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final name = widget.session.patientName.isEmpty
        ? context.l10n.remarksThisPatient
        : widget.session.patientName;

    // Soft sage used for field borders, as on the auth screens.
    final sage = Color.alphaBlend(
      AppColors.pineLight.withAlpha(90),
      Colors.white,
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          borderSide: BorderSide(color: color, width: width),
        );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.remarksTitle,
                style: text.titleLarge!.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.remarksFor(
                  name,
                  formatDateTime(
                    widget.session.date,
                    widget.session.time,
                    context.l10n,
                  ),
                ),
                style: text.bodyMedium!.copyWith(
                  fontSize: 14,
                  letterSpacing: 0,
                  color: AppColors.inkMid,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _notes,
                maxLines: 5,
                maxLength: 2000,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: text.bodyMedium!.copyWith(
                  height: 1.4,
                  letterSpacing: 0,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.remarksHint,
                  hintStyle: text.bodyMedium!.copyWith(
                    letterSpacing: 0,
                    color: AppColors.inkMute,
                  ),
                  counterStyle: text.bodySmall!.copyWith(
                    letterSpacing: 0,
                    color: AppColors.inkMid,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(AppSpacing.lg),
                  border: border(sage),
                  enabledBorder: border(sage),
                  focusedBorder: border(AppColors.pine, 1.5),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerPale,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: text.bodySmall!.copyWith(
                            height: 1.35,
                            letterSpacing: 0,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pine,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.pine.withAlpha(90),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    // Buttons default to labelLarge (mono, spaced).
                    textStyle: text.titleMedium!.copyWith(letterSpacing: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.l10n.remarksSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}