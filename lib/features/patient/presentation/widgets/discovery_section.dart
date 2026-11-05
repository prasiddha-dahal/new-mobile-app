import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';

/// One way into the app's three "how do I get care?" answers.
///
/// The copy and the destination live here rather than at each call site
/// because two screens offer these now — Home and Find — and a pair of
/// hand-copied labels is a pair that drifts.
/// Which of the three answers an entry is.
///
/// The copy used to live in the record itself. It cannot any more: a `const`
/// record is built before there is a `BuildContext` to read a language from,
/// so the entry names itself and the two lookups below resolve the words at
/// render time.
enum DiscoveryKind { findTherapist, findClinic, viewOnMap }

typedef DiscoveryEntry = ({
  DiscoveryKind kind,
  IconData icon,
  String route,
  Color tint,
  Color iconColor,
});

String discoveryTitle(DiscoveryEntry entry, AppLocalizations l10n) =>
    switch (entry.kind) {
      DiscoveryKind.findTherapist => l10n.discoveryFindTherapistTitle,
      DiscoveryKind.findClinic => l10n.discoveryFindClinicTitle,
      DiscoveryKind.viewOnMap => l10n.discoveryViewOnMapTitle,
    };

String discoveryDescription(DiscoveryEntry entry, AppLocalizations l10n) =>
    switch (entry.kind) {
      DiscoveryKind.findTherapist => l10n.discoveryFindTherapistDesc,
      DiscoveryKind.findClinic => l10n.discoveryFindClinicDesc,
      DiscoveryKind.viewOnMap => l10n.discoveryViewOnMapDesc,
    };

const DiscoveryEntry findTherapistEntry = (
  kind: DiscoveryKind.findTherapist,
  icon: Icons.person_search_rounded,
  route: '/patient/find',
  tint: AppColors.pinePale,
  iconColor: AppColors.pine,
);

const DiscoveryEntry findClinicEntry = (
  kind: DiscoveryKind.findClinic,
  icon: Icons.local_hospital_rounded,
  route: '/clinics',
  tint: AppColors.amberPale,
  iconColor: AppColors.amberBrand,
);

const DiscoveryEntry viewOnMapEntry = (
  kind: DiscoveryKind.viewOnMap,
  icon: Icons.map_rounded,
  route: '/patient/coverage',
  tint: AppColors.mist,
  iconColor: AppColors.pine,
);

/// Home offers all three. Find offers the other two — see [discoveryShortcuts].
const List<DiscoveryEntry> discoveryEntries = [
  findTherapistEntry,
  findClinicEntry,
  viewOnMapEntry,
];

/// The subset that makes sense *on* the Find screen: a "Find a
/// Physiotherapist" row there would point at the screen the user is already
/// standing on.
const List<DiscoveryEntry> discoveryShortcuts = [
  findClinicEntry,
  viewOnMapEntry,
];

/// Every entry navigates with `push`, for the same reason the hero button on
/// Home does: these are pages *in* the tab the user is already in, so stacking
/// keeps that tab lit, keeps its scroll position, and lets Back return to the
/// card that was tapped. `go` would replace the branch's stack and drop the
/// user onto the shell's back ladder instead.
void openDiscoveryEntry(BuildContext context, DiscoveryEntry entry) {
  context.push(entry.route);
}

/// A full-width card: tinted icon tile, title, one-line description, and a
/// circular arrow. Used in the "What are you looking for?" block on Home.
class DiscoveryCard extends StatelessWidget {
  const DiscoveryCard({super.key, required this.entry, this.onTap});

  final DiscoveryEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap ?? () => openDiscoveryEntry(context, entry),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.tint,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            alignment: Alignment.center,
            child: Icon(entry.icon, size: 22, color: entry.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discoveryTitle(entry, context.l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  discoveryDescription(entry, context.l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.inkMid),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.pine,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// The compact form, for the Find screen, where a stack of full cards would
/// push the results it is supposed to complement off the first screenful.
class DiscoveryShortcut extends StatelessWidget {
  const DiscoveryShortcut({super.key, required this.entry, this.onTap});

  final DiscoveryEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => openDiscoveryEntry(context, entry),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: entry.tint,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(entry.icon, size: 16, color: entry.iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                discoveryTitle(entry, context.l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
