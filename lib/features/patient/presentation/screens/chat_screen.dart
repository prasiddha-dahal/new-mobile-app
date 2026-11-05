import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';

/// Support screen.
///
/// There is no chat backend of any kind, so this deliberately does **not**
/// pretend to be a live chat: the assistant's opening message is shown as
/// static content, the composer is disabled with an explanation, and the phone
/// and WhatsApp details — which do work — are given prominence instead.
/// TODO(api): a real chat/support endpoint (A13 in docs/TODO_REGISTER.md).
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  static const _supportNumber = '+977 9801-234567';

  static List<String> _commonQuestions(AppLocalizations l10n) => [
    l10n.chatQCost,
    l10n.chatQStroke,
    l10n.chatQAbroad,
    l10n.chatQToday,
    l10n.chatQHuman,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            PageHeader(
              title: l10n.chatTitle,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/patient/account'),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.card),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E4B3F), AppColors.pine],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('💬', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.chatAssistantName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          l10n.chatAssistantHours,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppRadii.card),
                      topRight: Radius.circular(AppRadii.card),
                      bottomRight: Radius.circular(AppRadii.card),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    l10n.chatGreeting,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              l10n.chatCommonQuestions,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in _commonQuestions(l10n))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.pine.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      q,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.pine,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              l10n.chatPreferToTalk,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            AppCard(
              onTap: () => _copyNumber(context),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.pinePale,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📞', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          _supportNumber,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          l10n.chatCallOrWhatsapp,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.copy_outlined,
                    size: 16,
                    color: AppColors.inkMute,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // The composer is shown so the layout matches, but it is inert and
            // says so — an input that silently swallows messages would be worse
            // than none.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.chatNotAvailable,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMute,
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.pine.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_upward,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatCallInstead,
              style: const TextStyle(fontSize: 11, color: AppColors.inkMute),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialling needs url_launcher, which is not a dependency; copying the number
  /// is the honest fallback.
  /// TODO(design): add url_launcher for tel:/WhatsApp deep links.
  static void _copyNumber(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _supportNumber));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.chatNumberCopied)),
      );
  }
}
