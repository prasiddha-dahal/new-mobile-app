import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';

class TherapistPerformanceScreen extends StatelessWidget {
  const TherapistPerformanceScreen({super.key});

  /// Built per-build rather than held `const`, because the labels come from
  /// the ARB files. The figures are still the prototype's demo data.
  static List<(String, String, String)> _kpis(AppLocalizations l10n) => [
    (l10n.kpiSessionsLabel, '486', l10n.performanceTotalCompleted),
    (l10n.kpiEarningsLabel, 'Rs 72K', l10n.therapistKpiThisMonth),
    (l10n.kpiRatingLabel, '4.9', l10n.performanceFromReviews(182)),
    (l10n.kpiCompletionLabel, '94%', l10n.performanceBookingRate),
  ];

  static const _chartData = [60, 75, 55, 85, 70, 90, 65];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kpis = _kpis(l10n);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              PageHeader(
                title: l10n.performanceTitle,
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  itemBuilder: (context, index) {
                    final (l, v, s) = kpis[index];
                    return KpiCard(
                      label: l,
                      value: v,
                      subtitle: s,
                      isHighlighted: index == 1,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.performanceSessionsOverview),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children:
                            [
                                  l10n.dayShortMon,
                                  l10n.dayShortTue,
                                  l10n.dayShortWed,
                                  l10n.dayShortThu,
                                  l10n.dayShortFri,
                                  l10n.dayShortSat,
                                  l10n.dayShortSun,
                                ]
                                .map(
                                  (d) => Expanded(
                                    child: Text(
                                      d,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'IBM Plex Mono',
                                        fontSize: 10,
                                        color: AppColors.inkMute,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _chartData.map((v) {
                            final h = (v / 100) * 80;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Container(
                                  height: h.clamp(8.0, 80.0),
                                  decoration: BoxDecoration(
                                    color: AppColors.pinePale,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
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
