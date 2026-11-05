import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/location/directions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../patient/domain/entities/session.dart';

/// Whether a therapist has somewhere to go for [session]: a home visit that is
/// still on and not on a day already gone, with an address or a pinned point
/// to send to the maps app.
///
/// The day check matters because the backend leaves a session SCHEDULED after
/// its date passes, and the Upcoming tab lists those until someone marks them;
/// directions to a visit from last month are only noise. Today's visits keep
/// the button however late in the day it is.
bool canNavigateTo(Session session) =>
    session.isHomeVisit &&
    !session.hasElapsed &&
    (session.status == SessionStatus.scheduled ||
        session.status == SessionStatus.inProgress) &&
    (session.point != null || session.address.trim().isNotEmpty);

/// Opens directions to [session] in the device's maps app, or says why not.
Future<void> openDirections(
  BuildContext context,
  WidgetRef ref,
  Session session,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = context.l10n.navigateUnavailable;
  final opened = await ref.read(urlOpenerProvider)(
    directionsUri(point: session.point, address: session.address),
  );
  if (!opened) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Opens directions to a home visit in the device's maps app.
///
/// Uses the pinned point when the patient set one, and searches for the typed
/// address when they did not. Full width on a session card; [compact] is the
/// icon-only form for a dense row.
class NavigateButton extends ConsumerWidget {
  const NavigateButton({
    super.key,
    required this.session,
    this.compact = false,
  });

  final Session session;
  final bool compact;

  Future<void> _open(BuildContext context, WidgetRef ref) =>
      openDirections(context, ref, session);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = context.l10n.actionNavigate;
    if (compact) {
      return IconButton(
        tooltip: label,
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.directions_rounded, color: AppColors.pine),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.directions_rounded, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.pine,
          side: const BorderSide(color: AppColors.pine),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: AppTypography.textTheme.titleSmall!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.row),
          ),
        ),
      ),
    );
  }
}

/// "Landmark: Blue gate opposite the temple", or nothing.
class VisitLandmark extends StatelessWidget {
  const VisitLandmark({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final landmark = session.landmark?.trim() ?? '';
    if (!session.isHomeVisit || landmark.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        context.l10n.visitLandmark(landmark),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: AppColors.inkMid),
      ),
    );
  }
}
