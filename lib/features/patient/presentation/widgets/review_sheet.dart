import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/session.dart';
import '../../../../core/validation/validators.dart';

/// A rating plus optional comment, collected after a completed session.
class ReviewChoice {
  const ReviewChoice({required this.rating, this.comment});

  /// 1–5.
  final int rating;
  final String? comment;
}

Future<ReviewChoice?> showReviewSheet(
  BuildContext context, {
  required Session session,
}) {
  return showModalBottomSheet<ReviewChoice>(
    context: context,
    isScrollControlled: true,
    // Push onto the root navigator: the shell's bottom nav would
    // otherwise paint over a sheet opened on the shell's own navigator.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _ReviewSheet(session: session),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.session});
  final Session session;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 5;
  final _comment = TextEditingController();

  /// Blank is fine — the rating alone is a valid review. A comment that is
  /// present but too short to mean anything is not.
  String? get _commentError => Validators.optional(
    Validators.longText(context.l10n, context.l10n.fieldComment, min: 10, max: 500),
  )(_comment.text);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = widget.session.therapistName.isEmpty
        ? l10n.reviewYourTherapist
        : widget.session.therapistName;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.reviewTitle,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 20,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.reviewSubtitle(name),
                style: const TextStyle(fontSize: 13, color: AppColors.inkMid),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final value = i + 1;
                  final filled = value <= _rating;
                  return IconButton(
                    onPressed: () => setState(() => _rating = value),
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 34,
                      color: filled ? AppColors.amberBrand : AppColors.inkMute,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comment,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: l10n.reviewCommentHint,
                  // Shown rather than only disabling the button, so the
                  // reason it is disabled is on screen.
                  errorText: _commentError,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _commentError != null
                      ? null
                      : () => Navigator.pop(
                          context,
                          ReviewChoice(
                            rating: _rating,
                            comment: _comment.text.trim().isEmpty
                                ? null
                                : _comment.text.trim(),
                          ),
                        ),
                  child: Text(l10n.reviewSubmit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
