import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

/// Confirmation receipt for a booked clinic visit.
///
/// Like the home-visit receipt, everything here arrives as query parameters
/// from the booking response — nothing is invented. Nothing routes here yet:
/// `Session` has no `clinicId`, so the booking screen's confirm always fails
/// honestly instead. The screen is complete so that switching clinic booking on
/// needs no work here.
class ClinicBookedScreen extends StatelessWidget {
  const ClinicBookedScreen({
    super.key,
    this.clinicName,
    this.address,
    this.hours,
    this.date,
    this.time,
  });

  final String? clinicName;
  final String? address;
  final String? hours;

  /// `YYYY-MM-DD`.
  final String? date;

  /// `HH:MM`.
  final String? time;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final clinic = clinicName?.trim().isNotEmpty == true
        ? clinicName!
        : l10n.clinicBookedTitle;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.pinePale,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '✓',
                          style: TextStyle(fontSize: 24, color: AppColors.pine),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.clinicBookedHeading,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // The prototype promises the address was texted over. No
                      // SMS provider is wired up, so the copy points at the one
                      // place the details really are.
                      // TODO(api): SMS confirmations (A19 in docs/TODO_REGISTER.md).
                      Text(
                        l10n.clinicBookedBody(clinic, _whenLabel(l10n)),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.inkMid,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.labelAddress,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              address?.trim().isNotEmpty == true
                                  ? address!
                                  : '—',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                color: AppColors.ink,
                              ),
                            ),
                            if (hours?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                hours!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkMid,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => context.go('/patient/sessions'),
                  child: Text(l10n.actionViewMySessions),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.go('/patient/home'),
                  child: Text(l10n.actionBackToHome),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _whenLabel(AppLocalizations l10n) {
    final parsed = date == null ? null : DateTime.tryParse(date!);
    if (parsed == null) return l10n.clinicWhenAsScheduled;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = target.difference(today).inDays;

    // Lowercase mid-sentence, so formatDayLabel's capitalised output cannot be
    // reused here.
    final dayPart = switch (diff) {
      0 => l10n.clinicWhenToday,
      1 => l10n.clinicWhenTomorrow,
      _ => l10n.clinicWhenOnDate(formatShortDate(parsed, l10n)),
    };
    return time == null ? dayPart : l10n.clinicWhenAtTime(dayPart, time!);
  }
}
