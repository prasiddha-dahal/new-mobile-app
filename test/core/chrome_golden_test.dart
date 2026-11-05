import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';
import 'package:sahayatri_care_connect/core/widgets/shared_widgets.dart';
import 'package:sahayatri_care_connect/features/packages/domain/entities/package_purchase.dart';
import 'package:sahayatri_care_connect/features/packages/domain/entities/therapy_package.dart';
import 'package:sahayatri_care_connect/features/packages/domain/repositories/package_repository.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/providers/package_providers.dart';
import 'package:sahayatri_care_connect/features/packages/presentation/screens/therapy_packages_screen.dart';
import 'package:sahayatri_care_connect/features/shop/domain/entities/product.dart';
import 'package:sahayatri_care_connect/features/shop/presentation/providers/shop_providers.dart';
import 'package:sahayatri_care_connect/features/shop/presentation/screens/shop_screen.dart';

import '../l10n_harness.dart';

/// Pictures of the two pieces of chrome this branch changed.
///
/// Assertions on this project have repeatedly agreed that something was fine
/// while it was invisible or unreadable: a pill the same colour as the row it
/// sat on passed a colour check, a header that wrapped to one letter per line
/// passed an overflow check. A golden is the only test that would have caught
/// either, so the two changes here — labels under the nav icons, and the
/// `My packages` pill in a header slot that used to be capped at 36dp — are
/// pinned as images as well as by [nav_bar_labels_test.dart].
///
/// Each is taken twice: once at 390dp in English, which is what the designs
/// were drawn at, and once at **320dp with 1.6x text**, which is the small
/// Android phone and the accessibility font size where rows in this app stop
/// fitting. The second shot is in Nepali, because Devanagari is the longer
/// script and the labels are what has to give.
///
/// Regenerate with `flutter test --update-goldens test/core/chrome_golden_test.dart`
/// and *look at the diff* before accepting it. The test font renders glyphs as
/// filled boxes, so these pin geometry, colour and containment rather than
/// letterforms — which is exactly what the two bugs above were.
class _FakeRepository implements PackageRepository {
  const _FakeRepository(this.catalogue);

  final List<TherapyPackage> catalogue;

  @override
  Future<AppResult<List<TherapyPackage>>> listPackages() async =>
      Right(catalogue);

  @override
  Future<AppResult<TherapyPackage>> getPackage(String id) async =>
      Right(catalogue.first);

  @override
  Future<AppResult<PackagePurchase>> purchasePackage({
    required String packageId,
    required String paymentMethod,
  }) async => const Left(ServerFailure());

  @override
  Future<AppResult<List<PackagePurchase>>> listMyPurchases() async =>
      const Right([]);

  @override
  Future<AppResult<PackagePurchase?>> getActivePurchase() async =>
      const Right(null);
}

const _package = TherapyPackage(
  id: 'package-1',
  name: 'Knee Replacement Therapy',
  tag: 'Orthopedic',
  price: 4500,
  cadence: 'per week · 6 sessions',
  blurb: 'Post-surgery physiotherapy to improve mobility and strength.',
  sessionCount: 6,
  validityDays: 7,
);

void _noop() {}

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required Locale locale,
    required Size size,
    required double textScale,
    List<Override> overrides = const [],
  }) async {
    await pumpLocalized(
      tester,
      // A real ground under the shot: a transparent body would make a
      // low-contrast control look fine against nothing.
      ColoredBox(color: AppColors.cream, child: child),
      locale: locale,
      size: size,
      textScale: textScale,
      overrides: overrides,
      // The app's own theme, so the shot is of what ships rather than of
      // Material's defaults.
      theme: AppTheme.light,
    );
    await tester.pumpAndSettle();
  }

  group('the bottom bar', () {
    testWidgets('patient, 390dp, English', (tester) async {
      await pump(
        tester,
        Scaffold(
          backgroundColor: AppColors.cream,
          bottomNavigationBar: PatientNav(currentIndex: 0, onSelect: (_) {}),
        ),
        locale: const Locale('en'),
        size: const Size(390, 200),
        textScale: 1.0,
      );

      await expectLater(
        find.byType(PatientNav),
        matchesGoldenFile('goldens/patient_nav_390_en.png'),
      );
    });

    testWidgets('therapist, 320dp at 1.6x, Nepali', (tester) async {
      // The worst case in the app: the narrowest phone, the largest text, and
      // the longest label ("अनुरोधहरू"). If the labels were going to clip, run
      // into each other or disappear, it would be here.
      await pump(
        tester,
        Scaffold(
          backgroundColor: AppColors.cream,
          bottomNavigationBar: TherapistNav(currentIndex: 2, onSelect: (_) {}),
        ),
        locale: const Locale('ne'),
        size: const Size(320, 200),
        textScale: 1.6,
      );

      await expectLater(
        find.byType(TherapistNav),
        matchesGoldenFile('goldens/therapist_nav_320_ne_1_6x.png'),
      );
    });
  });

  group('the packages header', () {
    // The repository is overridden on the harness's own container rather
    // than in a nested `ProviderScope`: Riverpod refuses to read a provider
    // whose dependency was overridden in a scope below the one it lives in.
    final overrides = [
      packageRepositoryProvider.overrideWithValue(
        const _FakeRepository([_package]),
      ),
    ];

    Widget screen() => const Scaffold(
      backgroundColor: AppColors.cream,
      body: TherapyPackagesScreen(onBack: _noop, onViewMyPackages: _noop),
    );

    testWidgets('with the My packages pill, 390dp, English', (tester) async {
      // The pill is pine-pale on cream. A colour assertion cannot tell you
      // whether it reads; this can.
      await pump(
        tester,
        screen(),
        locale: const Locale('en'),
        size: const Size(390, 640),
        textScale: 1.0,
        overrides: overrides,
      );

      await expectLater(
        // Addressed at the header, but `matchesGoldenFile` paints from the
        // nearest ancestor repaint boundary, so this is the whole screen —
        // header, search field and first card. Which is the more useful
        // picture anyway: it is where the 45% cap on the trailing slot and
        // the package card's footer are both visible at once.
        find.byType(PageHeader),
        matchesGoldenFile('goldens/packages_header_390_en.png'),
      );
    });

    testWidgets('and at 320dp / 1.6x in Nepali', (tester) async {
      // Back button, a Fraunces title and a pill in one row, at the size where
      // the title has to give way. What this is watching for is the title
      // collapsing to a single ellipsis or the pill being squeezed to a
      // sliver — the header-wrapped-to-one-letter-per-line failure, again.
      await pump(
        tester,
        screen(),
        locale: const Locale('ne'),
        size: const Size(320, 640),
        textScale: 1.6,
        overrides: overrides,
      );

      await expectLater(
        find.byType(PageHeader),
        matchesGoldenFile('goldens/packages_header_320_ne_1_6x.png'),
      );
    });
  });

  group('the shop header', () {
    // The shop is a root route: it covers the shell, so there is no bottom
    // bar under it and it had no Back of its own either — it drew none,
    // which did not show while nothing in the app could open it. Now that
    // the centre-action sheet can, it has one, and this is the only layout
    // this branch changed. The two shots ask whether the new 36dp circle
    // took the room the serif title needed.
    Widget screen() => const Scaffold(
      backgroundColor: AppColors.cream,
      body: ShopScreen(),
    );

    // Both, not just the list: the cart badge in the header reads
    // `cartProvider`, and leaving that one live has the golden reaching for
    // Dio and failing on a pending timer rather than on a picture.
    final overrides = [
      productListProvider.overrideWith((_) async => <Product>[]),
      cartProvider.overrideWith(
        (_) async => const Cart(
          lines: [],
          subtotal: 0,
          deliveryFee: 0,
          grandTotal: 0,
        ),
      ),
    ];

    testWidgets('with its new Back, 390dp, English', (tester) async {
      await pump(
        tester,
        screen(),
        locale: const Locale('en'),
        size: const Size(390, 400),
        textScale: 1.0,
        overrides: overrides,
      );

      await expectLater(
        find.byType(ShopScreen),
        matchesGoldenFile('goldens/shop_header_390_en.png'),
      );
    });

    testWidgets('and at 320dp / 1.6x in Nepali', (tester) async {
      // Back, an eyebrow over a 28pt Fraunces title, and the cart button, in
      // one row at the size where something has to give. The title is the
      // half that may wrap; what this watches for is it collapsing or the
      // row bursting the way `PageHeader`'s did.
      await pump(
        tester,
        screen(),
        locale: const Locale('ne'),
        size: const Size(320, 400),
        textScale: 1.6,
        overrides: overrides,
      );

      await expectLater(
        find.byType(ShopScreen),
        matchesGoldenFile('goldens/shop_header_320_ne_1_6x.png'),
      );
    });
  });
}
