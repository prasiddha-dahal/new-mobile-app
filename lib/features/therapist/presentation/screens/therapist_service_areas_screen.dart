import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';

class TherapistServiceAreasScreen extends StatelessWidget {
  const TherapistServiceAreasScreen({super.key});

  /// TODO(api): there is no per-therapist service-area list. A therapist
  /// record carries a single `city`; `/coverage/areas` is the platform's own
  /// map, not this therapist's. So there is nothing for Add to add to.
  static void _areasUnavailable(BuildContext context) => showUnavailableDialog(
    context,
    title: context.l10n.serviceAreasAddUnavailableTitle,
    body: context.l10n.serviceAreasAddUnavailableBody,
  );

  static const _areas = [
    'Lalitpur',
    'Kathmandu',
    'Patan',
    'Jawalakhel',
    'Pulchowk',
    'Sanepa',
    'Jhamsikhel',
  ];

  /// Place names are keys here for the same reason they are everywhere else:
  /// the value is what would be sent, the label is what is read. Both happen
  /// to be identical in Nepali, which is the reviewed corpus's convention for
  /// place names — but the indirection is what makes that a decision rather
  /// than an accident.
  String _areaLabel(String value, AppLocalizations l10n) => switch (value) {
    'Kathmandu' => l10n.cityKathmandu,
    'Lalitpur' => l10n.cityLalitpur,
    'Bhaktapur' => l10n.cityBhaktapur,
    'Patan' => l10n.areaPatan,
    'Jawalakhel' => l10n.areaJawalakhel,
    'Pulchowk' => l10n.areaPulchowk,
    'Sanepa' => l10n.areaSanepa,
    'Jhamsikhel' => l10n.areaJhamsikhel,
    'Kirtipur' => l10n.areaKirtipur,
    'Budhanilkantha' => l10n.areaBudhanilkantha,
    'Tokha' => l10n.areaTokha,
    'Gokarneshwor' => l10n.areaGokarneshwor,
    _ => value,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              PageHeader(
                title: l10n.serviceAreasTitle,
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.serviceAreasActive),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _areas.map((a) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pine,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            // The helper above exists for exactly this, and
                            // the suggestion chips lower down already call it.
                            // The one place the therapist reads their *own*
                            // configured areas was rendering the raw API
                            // value, so a Nepali screen listed them in English.
                            _areaLabel(a, l10n),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.card,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.card,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.serviceAreasAdd),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: l10n.serviceAreasSearchHint,
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: AppColors.inkMute,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _areasUnavailable(context),
                        child: Text(
                          l10n.actionAdd,
                          style: const TextStyle(color: AppColors.pine),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            'Bhaktapur',
                            'Kirtipur',
                            'Budhanilkantha',
                            'Tokha',
                            'Gokarneshwor',
                          ]
                          .map(
                            (a) => GestureDetector(
                              onTap: () => _areasUnavailable(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  _areaLabel(a, l10n),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkMid,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
