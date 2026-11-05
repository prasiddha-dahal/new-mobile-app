import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/widgets/app_back_button.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/navigation/tab_requests.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/notification_models.dart';
import '../providers/notification_providers.dart';
import '../widgets/notification_visuals.dart';

/// The shared notifications feed, mounted once per role at
/// `/patient/notifications` and `/therapist/notifications`.
///
/// ## No header of its own
///
/// `TabShell` mounts [AppHeader] above every route in both shells, so this
/// screen draws no back arrow of its own: it is a tab root, and Back at a tab
/// root is the shell's ladder, not a button.
///
/// **Mark all read sits to the right of the title.** It is rendered only when
/// there is something unread to clear.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  /// The feed list, so tests can address it without matching on copy.
  static const Key listKey = Key('notifications.list');

  /// The "Mark all read" control, which is only mounted when unread > 0.
  static const Key markAllReadKey = Key('notifications.markAllRead');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final feed = ref.watch(notificationFeedProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBackButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(
                      (ref.read(currentUserProvider)?.isTherapist ?? false)
                          ? '/therapist/home'
                          : '/patient/home',
                    ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: LayoutBuilder(
                builder: (context, box) => Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.notificationsTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge!.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Only offered when it would do something.
                    //
                    // Capped at 45% of the row. A control sized to its own
                    // text would otherwise take whatever the current text
                    // scale asks for and leave the title the remainder — on a
                    // narrow phone at a large scale, nothing at all.
                    if (unread > 0)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: box.maxWidth * 0.45,
                        ),
                        child: GestureDetector(
                          key: markAllReadKey,
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _markAllRead(context, ref),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              top: AppSpacing.sm,
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              l10n.notificationsMarkAllRead,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: text.titleSmall!.copyWith(
                                fontSize: 13,
                                color: AppColors.pine,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: feed.when(
                loading: () => const SkeletonList(
                  count: 5,
                  itemHeight: 84,
                  gap: AppSpacing.sm,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                ),
                error: (e, _) => ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () =>
                      ref.read(notificationFeedProvider.notifier).refresh(),
                ),
                data: (data) => RefreshIndicator(
                  onRefresh: () =>
                      ref.read(notificationFeedProvider.notifier).refresh(),
                  child: data.notifications.isEmpty
                      ? _buildEmpty(l10n)
                      : _buildList(context, ref, data.notifications),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The expected state, not a broken one.
  ///
  /// Most users have an empty feed today, so it is phrased as being up to
  /// date rather than as an absence, and it names only things the API
  /// actually sends.
  ///
  /// Scrollable despite fitting on one screen, so pull-to-refresh works here
  /// too: an empty feed is exactly where someone tugs at the screen to check.
  Widget _buildEmpty(AppLocalizations l10n) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 48),
      EmptyStateView(
        title: l10n.notificationsEmptyTitle,
        description: l10n.notificationsEmptyDesc,
        icon: Icons.notifications_none,
      ),
    ],
  );

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<NotificationDto> items,
  ) => ListView.builder(
    key: listKey,
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      0,
      AppSpacing.page,
      AppSpacing.xxl,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) {
      final item = items[i];
      return NotificationCard(
        item: item,
        // Keyed on the row id, not the list index: without this a row that
        // flips to read would hand its element to whatever is at that index
        // after a refresh.
        key: ValueKey(item.id),
        onTap: () => _open(context, ref, item),
      );
    },
  );

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(notificationFeedProvider.notifier)
        .markAllRead();
    if (!context.mounted) return;
    result.match((failure) => _complain(context, failure), (_) {});
  }

  /// Marks the row read and follows its reference, if the app has one.
  ///
  /// Not awaited before navigating. The optimistic flip happens synchronously
  /// inside `markRead`, so the row is already read by the time this line
  /// returns; waiting on the round trip would only make every deep link feel
  /// like it hangs on a slow connection.
  void _open(BuildContext context, WidgetRef ref, NotificationDto item) {
    if (item.isUnread) {
      unawaited(_markRead(context, ref, item.id));
    }

    final destination = notificationDestinationFor(
      refType: item.refType,
      isTherapist: ref.read(currentUserProvider)?.isTherapist ?? false,
    );
    if (destination == null) return;

    // "Rate your last session" has to land on Past, where the review button
    // is; the Sessions tab opens on Upcoming otherwise.
    if (item.type == 'SESSION_RATE_REQUEST' &&
        !(ref.read(currentUserProvider)?.isTherapist ?? false)) {
      ref.read(openPastSessionsProvider.notifier).state = true;
    }

    // if (destination.isTab) {
    //   context.go(destination.path);
    // } else {
    //   context.push(destination.path);
    // }
  }

  Future<void> _markRead(BuildContext context, WidgetRef ref, String id) async {
    final result = await ref
        .read(notificationFeedProvider.notifier)
        .markRead(id);
    if (!context.mounted) return;
    result.match((failure) => _complain(context, failure), (_) {});
  }

  /// Says the write failed. The row has already rolled back to unread by the
  /// time this runs, so the message explains a visible change rather than
  /// announcing an invisible one.
  void _complain(BuildContext context, Failure failure) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.danger,
        ),
      );
  }
}

/// One row of the feed.
///
/// Public so a widget test can build a single row for a given `type` without
/// standing up a router, a Dio and a feed around it.
class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.item, required this.onTap});

  final NotificationDto item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final visual = notificationVisualFor(item.type);
    final unread = item.isUnread;

    // The whole row carries the unread state, not just the dot: a soft green
    // block is legible down the length of the screen in a way a 6px dot is
    // not. Everything inside has to contrast with it.
    final fill = unread
        ? Color.alphaBlend(AppColors.pinePale.withAlpha(150), Colors.white)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: unread ? AppColors.pinePale : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The disc has to contrast with whatever the row is filled
              // with, so it inverts: white on an unread green row, a wash of
              // the type's own tint on a read white one.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: unread
                      ? Colors.white
                      : visual.tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  visual.glyph,
                  style: TextStyle(fontSize: 20, color: visual.tint),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall!.copyWith(
                              fontSize: 15,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.amberBrand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      //maxLines: 2,
                      //overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium!.copyWith(
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    if (item.createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        formatRelativeTime(item.createdAt!, context.l10n),
                        style: text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Pill(pill: visual.pill, rowFill: fill),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.pill, required this.rowFill});

  final NotificationPill pill;

  /// What the card under it is painted, so the pill can avoid wearing the
  /// same colour and disappearing into it.
  final Color rowFill;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: pill.backgroundOn(rowFill),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        pill.labelIn(context.l10n),
        style: text.titleSmall!.copyWith(
          fontSize: 10,
          letterSpacing: 0.4,
          color: pill.foreground,
        ),
      ),
    );
  }
}
