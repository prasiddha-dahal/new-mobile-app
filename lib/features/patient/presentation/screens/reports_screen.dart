import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/models/care_models.dart';
import '../providers/care_providers.dart';

/// Documents therapists have shared with the patient.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Back arrow
            AppBackButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/patient/account'),
                  gutter: false,
            ),

            // Title and a line saying what this is
            Text(
              l10n.reportsTitle,
              style: text.titleLarge!.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.reportsHeading,
              style: text.bodyMedium!.copyWith(height: 1.4),
            ),
            const SizedBox(height: 20),

            reports.when(
              loading: () => const SkeletonBox(height: 208),
              error: (e, _) => ErrorStateView(
                failure: e is Failure ? e : const UnknownFailure(),
                onRetry: () => ref.invalidate(reportsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return EmptyStateView(
                    title: l10n.reportsEmptyTitle,
                    description: l10n.reportsEmptyDesc,
                    icon: Icons.description_outlined,
                  );
                }
                // Material, not a coloured Container, so each row's ripple shows
                // and is clipped to the card's rounded corners.
                return Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.border),
                        _ReportRow(
                          report: items[i],
                          onTap: () => _openReport(context, items[i]),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // TODO(api): POST /reports is restricted to THERAPIST and ADMIN,
            // so a patient cannot upload. Needs a permission change server-side
            // (A7 in docs/TODO_REGISTER.md).
            // Disabled, and labelled as such, rather than a live button that
            // only says "not available yet" once pressed (QA APP-01).
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.upload_file_outlined, size: 20),
                label: Text(l10n.reportsUploadSoon),
                style: OutlinedButton.styleFrom(
                  // Buttons default to labelLarge (mono, spaced), so the style
                  // has to be given here.
                  textStyle: text.titleSmall,
                  disabledForegroundColor: AppColors.inkMute,
                  side: BorderSide(color: AppColors.border.withAlpha(30)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reportsUploadUnavailable,
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report, required this.onTap});
  final ReportDto report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final files = report.fileUrls;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Document tile
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  AppColors.pinePale.withAlpha(150),
                  Colors.white,
                ),
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.description_outlined,
                size: 22,
                color: AppColors.pine,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall!.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatRelativeTime(report.createdAt, l10n),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusTag(
              label: files.length > 1
                  ? l10n.reportsFileCount(files.length)
                  : l10n.reportsSingle,
              tone: TagTone.neutral,
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.inkMid,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Opening a report ─────────────────────────────────────────────────

/// Opens a report's file. A report with several files lists them first.
Future<void> _openReport(BuildContext context, ReportDto report) async {
  final files = report.fileUrls;

  if (files.isEmpty) {
    _toast(context, 'This report has no file attached.');
    return;
  }
  if (files.length == 1) {
    await _launchFile(context, files.first);
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (sheetContext) => _FilesSheet(
      title: report.title,
      files: files,
      onOpen: (url) async {
        Navigator.of(sheetContext).pop();
        await _launchFile(context, url);
      },
    ),
  );
}

/// Hands the file to the phone: a PDF viewer, the browser or the gallery,
/// whichever the person has for that type.
Future<void> _launchFile(BuildContext context, String url) async {
  final uri = _resolveFileUrl(url);
  debugPrint('REPORT URL: "$url"  scheme=${uri?.scheme}  host=${uri?.host}');
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('launchUrl error: $e');
      opened = false;
    }
  }
  debugPrint('REPORT opened=$opened');
  if (!opened && context.mounted) {
    _toast(context, "Couldn't open this file.");
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// The file name at the end of a URL, without the query string.
String _fileName(String url, int index) {
  final path = Uri.tryParse(url)?.pathSegments ?? const <String>[];
  final last = path.isEmpty ? '' : path.last;
  return last.isEmpty ? 'File ${index + 1}' : Uri.decodeComponent(last);
}

IconData _fileIcon(String url) {
  final lower = url.toLowerCase().split('?').first;
  if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (RegExp(r'\.(png|jpe?g|webp|gif|heic)$').hasMatch(lower)) {
    return Icons.image_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

class _FilesSheet extends StatelessWidget {
  const _FilesSheet({
    required this.title,
    required this.files,
    required this.onOpen,
  });

  final String title;
  final List<String> files;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleLarge!.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: files.length,
                itemBuilder: (_, i) => ListTile(
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
                      color: Color.alphaBlend(
                        AppColors.pinePale.withAlpha(150),
                        Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
                    child: Icon(
                      _fileIcon(files[i]),
                      size: 22,
                      color: AppColors.pine,
                    ),
                  ),
                  title: Text(
                    _fileName(files[i], i),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // ListTile otherwise draws its title in the theme's own
                  // body style.
                  titleTextStyle: text.titleSmall!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  trailing: const Icon(
                    Icons.open_in_new_rounded,
                    size: 20,
                    color: AppColors.inkMid,
                  ),
                  onTap: () => onOpen(files[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Turns "/api/v1/uploads/..." into "https://your-host/api/v1/uploads/...".
/// A link that is already complete is left alone.

Uri? _resolveFileUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.hasScheme) return uri;

  // Use whatever name your .env uses for the API address.
  final base = Uri.tryParse(dotenv.maybeGet('API_BASE_URL') ?? '');
  if (base == null || base.host.isEmpty) return null;

  final origin = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
  );
  return origin.resolve(raw);
}
