import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/features/packages/domain/entities/package_purchase.dart';
import 'package:sahayatri_care_connect/features/packages/domain/entities/therapy_package.dart';
import 'package:sahayatri_care_connect/features/packages/domain/repositories/package_repository.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/providers/package_providers.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/screens/my_packages_screen.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/screens/therapy_packages_screen.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/widgets/active_package_card.dart';

class _FakeRepository implements PackageRepository {
  _FakeRepository({
    this.catalogue = const [],
    this.active,
    this.history = const [],
    this.catalogueFailure,
  });

  final List<TherapyPackage> catalogue;
  final PackagePurchase? active;
  final List<PackagePurchase> history;
  final Failure? catalogueFailure;

  @override
  Future<AppResult<List<TherapyPackage>>> listPackages() async =>
      catalogueFailure == null ? Right(catalogue) : Left(catalogueFailure!);

  @override
  Future<AppResult<TherapyPackage>> getPackage(String id) async =>
      Right(catalogue.firstWhere((p) => p.id == id));

  @override
  Future<AppResult<PackagePurchase>> purchasePackage({
    required String packageId,
    required String paymentMethod,
  }) async => const Left(ServerFailure());

  @override
  Future<AppResult<List<PackagePurchase>>> listMyPurchases() async =>
      Right(history);

  @override
  Future<AppResult<PackagePurchase?>> getActivePurchase() async => Right(active);
}

const _stroke = TherapyPackage(
  id: 'package-1',
  name: 'Stroke & Neuro Recovery',
  tag: 'Most requested from abroad',
  price: 24000,
  cadence: 'per month · 12 sessions',
  blurb: 'Structured neuro-rehab for stroke and Parkinson at home.',
  points: ['Same therapist for the whole plan'],
  sessionCount: 12,
  validityDays: 30,
);

const _sports = TherapyPackage(
  id: 'package-2',
  name: 'Sports Injury Comeback',
  tag: 'Return to play',
  price: 16000,
  cadence: 'per month · 8 sessions',
  blurb: 'ACL, rotator cuff and hamstring rehab.',
  sessionCount: 8,
  validityDays: 30,
);

PackagePurchase _activePurchase() => PackagePurchase(
  id: 'purchase-1',
  packageId: 'package-1',
  packageName: 'Stroke & Neuro Recovery',
  sessionsTotal: 12,
  sessionsUsed: 2,
  status: 'ACTIVE',
  purchasedAt: DateTime.now().subtract(const Duration(days: 3)),
  expiresAt: DateTime.now().add(const Duration(days: 27)),
);

Widget _host(Widget child, _FakeRepository repo) {
  return ProviderScope(
    overrides: [packageRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('the catalogue lists each package with its real price', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const TherapyPackagesScreen(),
        _FakeRepository(catalogue: const [_stroke, _sports]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stroke & Neuro Recovery'), findsOneWidget);
    expect(find.text('Sports Injury Comeback'), findsOneWidget);
    // The seeded price, not the mock's "From Rs 4,500".
    expect(find.text('Rs 24,000'), findsOneWidget);
    expect(find.text('Rs 16,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the chip row stays hidden when every package has its own tag', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const TherapyPackagesScreen(),
        _FakeRepository(catalogue: const [_stroke, _sports]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All'), findsNothing);
  });

  testWidgets('an empty catalogue shows the empty state, not a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const TherapyPackagesScreen(), _FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No packages yet'), findsOneWidget);
  });

  testWidgets('a missing catalogue endpoint offers a retry', (tester) async {
    await tester.pumpWidget(
      _host(
        const TherapyPackagesScreen(),
        _FakeRepository(catalogueFailure: const NotFoundFailure()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('My packages shows progress, dates and sessions left', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const MyPackagesScreen(), _FakeRepository(active: _activePurchase())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stroke & Neuro Recovery'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('2 of 12 sessions used'), findsOneWidget);
    expect(find.text('17%'), findsOneWidget);
    expect(find.text('10 sessions remaining'), findsOneWidget);
    expect(find.text('STARTED'), findsOneWidget);
    expect(find.text('ENDS'), findsOneWidget);
    expect(find.text('No upcoming session booked yet.'), findsOneWidget);
  });

  testWidgets('My packages lists earlier purchases under the active one', (
    tester,
  ) async {
    final past = PackagePurchase(
      id: 'purchase-0',
      packageId: 'package-2',
      packageName: 'Sports Injury Comeback',
      sessionsTotal: 8,
      sessionsUsed: 8,
      status: 'DEPLETED',
      expiresAt: DateTime.now().subtract(const Duration(days: 40)),
    );
    final active = _activePurchase();

    await tester.pumpWidget(
      _host(
        const MyPackagesScreen(),
        _FakeRepository(active: active, history: [active, past]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PAST PACKAGES'), findsOneWidget);
    expect(find.text('Sports Injury Comeback'), findsOneWidget);
    // The active purchase is not repeated in the history list.
    expect(find.text('Stroke & Neuro Recovery'), findsOneWidget);
  });

  testWidgets('My packages degrades to an empty state with no package', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MyPackagesScreen(), _FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No active package'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActivePackageCard renders nothing without a package', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const ActivePackageCard(), _FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('sessions'), findsNothing);
  });

  testWidgets('ActivePackageCard shows the package when there is one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ActivePackageCard(), _FakeRepository(active: _activePurchase())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stroke & Neuro Recovery'), findsOneWidget);
    expect(find.text('2 of 12 sessions used'), findsOneWidget);
    // The compact form leaves the date block to My packages.
    expect(find.text('STARTED'), findsNothing);
  });

  testWidgets('ActivePackageCard hides an expired package', (tester) async {
    final expired = PackagePurchase(
      id: 'purchase-2',
      packageId: 'package-1',
      packageName: 'Stroke & Neuro Recovery',
      sessionsTotal: 12,
      sessionsUsed: 2,
      status: 'ACTIVE',
      expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      _host(const ActivePackageCard(), _FakeRepository(active: expired)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stroke & Neuro Recovery'), findsNothing);
  });

  testWidgets('the package detail sheet states the terms before buying', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const TherapyPackagesScreen(),
        _FakeRepository(catalogue: const [_stroke]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View package'));
    await tester.pumpAndSettle();

    expect(find.text('Buy this package'), findsOneWidget);
    expect(find.text("WHAT'S INCLUDED"), findsOneWidget);

    await tester.tap(find.text('Buy this package'));
    await tester.pumpAndSettle();

    // The money step must state name, price, sessions and validity.
    expect(find.text('Confirm your purchase'), findsOneWidget);
    expect(find.text('12 sessions'), findsOneWidget);
    expect(find.text('30 days from today'), findsOneWidget);
    expect(find.text('Confirm and pay Rs 24,000'), findsOneWidget);
  });
}
