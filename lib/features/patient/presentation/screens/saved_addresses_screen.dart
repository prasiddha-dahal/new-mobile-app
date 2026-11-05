import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/patient_profile_providers.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Manage visit addresses.
///
/// The backend stores exactly one address per user (`User.city`), with no
/// addresses table, so multiple entries and a primary flag cannot be supported.
/// The one address that does exist is shown as read-only, and the rest of the
/// screen states plainly that it is not available yet.
/// TODO(api): addresses CRUD + primary flag (A9 in docs/TODO_REGISTER.md).
class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final home =
        ref.watch(patientProfileProvider).valueOrNull?.address?.trim() ?? '';
    final city = (user?.city ?? '').trim();
    // The street address from the profile when there is one. Otherwise only
    // the city is known, and the card says so instead of presenting "Chitwan"
    // as a home address the booking would later refuse.
    final address = home.isNotEmpty ? home : city;
    final onlyCity = home.isEmpty && city.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            PageHeader(
              title: l10n.addressesTitle,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/patient/account'),
            ),
            const SizedBox(height: 16),
            if (address.isNotEmpty) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.addressHome,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusTag(
                          label: l10n.addressPrimaryBadge,
                          tone: TagTone.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.inkMid,
                      ),
                    ),
                    if (onlyCity) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.addressOnlyCitySaved,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      l10n.addressEditInProfile,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMute.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            AppCard(
              child: ApiTodoState(
                title: l10n.addressMultipleSoonTitle,
                description: l10n.addressMultipleSoonDesc,
                endpoint: 'addresses CRUD + primary flag',
                icon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.go('/patient/edit-profile'),
                child: Text(l10n.addressEditMine),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
