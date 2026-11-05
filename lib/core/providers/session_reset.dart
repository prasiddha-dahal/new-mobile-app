import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/patient/presentation/providers/care_providers.dart';
import '../../features/patient/presentation/providers/patient_profile_providers.dart';
import '../../features/patient/presentation/providers/patient_providers.dart';
import '../../features/shop/presentation/providers/shop_providers.dart';
import '../../features/therapist/presentation/providers/therapist_providers.dart';

/// Drops every cached view that belongs to one signed-in account.
///
/// Call this when a session *starts*, not when it ends. None of these
/// providers is `autoDispose`, so invalidating them while a screen is still
/// listening makes them refetch immediately — at logout that happens with the
/// token already cleared, and each one settles into a 401 error that would
/// still be there when the next user signs in. Invalidating from the login
/// screen has no listeners to wake, so the caches are simply emptied and the
/// new account's screens load their own data.
void resetAccountScopedProviders(WidgetRef ref) {
  // Patient
  ref.invalidate(patientSessionsProvider);
  ref.invalidate(patientDashboardProvider);
  ref.invalidate(therapistListProvider);
  ref.invalidate(featuredTherapistsProvider);
  ref.invalidate(reportsProvider);
  ref.invalidate(referralProvider);
  // The previous patient's home address prefilled the next one's booking,
  // and their reviews showed on the new account's visits.
  ref.invalidate(patientProfileProvider);
  ref.invalidate(myReviewsProvider);
  ref.invalidate(reviewableSessionIdsProvider);

  // Shop
  ref.invalidate(cartProvider);
  ref.invalidate(productListProvider);

  // Therapist
  ref.invalidate(therapistProfileProvider);
  ref.invalidate(therapistDashboardProvider);
  ref.invalidate(therapistSessionsProvider);
  ref.invalidate(myPatientsProvider);
  ref.invalidate(ownSlotsProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(payoutsProvider);
  ref.invalidate(blockRequestsProvider);
}
