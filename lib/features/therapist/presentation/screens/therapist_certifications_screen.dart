import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';

class TherapistCertificationsScreen extends StatelessWidget {
  const TherapistCertificationsScreen({super.key});

  /// Placeholder content until the profile endpoint carries credentials.
  /// Built per-build because the titles come from the ARB files; the issuing
  /// bodies, the reference numbers and the dates are data.
  static List<_CertData> _certs(AppLocalizations l10n) => [
    _CertData(
      title: l10n.certNmcLicence,
      issuer: 'Nepal Medical Council',
      id: 'NMC-PT-04821',
      issued: 'Issued Mar 2020 · Valid till 2026',
      badge: 'Verified',
    ),
    _CertData(
      title: l10n.certBpt,
      issuer: 'Kathmandu University',
      id: 'KU-BPT-2018-1245',
      issued: 'Graduated 2018',
      badge: 'Verified',
    ),
    _CertData(
      title: l10n.certSportsRehab,
      issuer: 'International Sports Physiotherapy Assoc.',
      id: 'ISPA-SR-2022-089',
      issued: 'Completed Dec 2022',
      badge: 'Verified',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              PageHeader(
                title: context.l10n.certificationsTitle,
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: _certs(context.l10n).map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.pinePale,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.verified_outlined,
                                color: AppColors.pine,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.pinePale,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check,
                                              size: 12,
                                              color: AppColors.pine,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              c.badge == 'Verified'
                                                  ? context
                                                        .l10n
                                                        .certificationVerified
                                                  : c.badge,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.pine,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.issuer,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.inkMid,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.id,
                                    style: const TextStyle(
                                      fontFamily: 'IBM Plex Mono',
                                      fontSize: 10,
                                      color: AppColors.inkMute,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.issued,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.inkMute,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    // TODO(api): no credential store, and no file picker to
                    // attach the document (A24).
                    onPressed: () => showUnavailableDialog(
                      context,
                      title: context.l10n.certificationsAddUnavailableTitle,
                      body: context.l10n.certificationsAddUnavailableBody,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.certificationsAdd),
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

class _CertData {
  const _CertData({
    required this.title,
    required this.issuer,
    required this.id,
    required this.issued,
    required this.badge,
  });
  final String title, issuer, id, issued, badge;
}
