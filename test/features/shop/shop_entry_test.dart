import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/core/router/app_router.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/shop/domain/entities/product.dart';
import 'package:sahayatri_care_connect/features/shop/presentation/providers/shop_providers.dart';
import 'package:sahayatri_care_connect/features/shop/presentation/screens/shop_screen.dart';

/// The shop was routed and reachable from nowhere: every `'/shop'` in `lib/`
/// came from inside the feature itself, so ~800 lines of working commerce had
/// no entrance. The centre-action sheet is the entrance now
/// (`quick_action_sheet_test.dart` pins the row and the push); this file pins
/// the other half — that a user who goes in can get out.
///
/// `/shop` is a root route, so it covers the shell: no bottom bar under it and
/// nothing else on screen to navigate with. Before this it drew no Back of any
/// kind, which did not matter while nothing could open it.
void main() {
  /// Mounts the real [ShopScreen] over a two-route router, with an empty
  /// product list so nothing reaches for Dio.
  Future<GoRouter> pumpShop(
    WidgetTester tester, {
    required bool arriveByPush,
  }) async {
    final router = GoRouter(
      initialLocation: '/patient/home',
      routes: [
        GoRoute(
          path: '/patient/home',
          builder: (_, _) => const Scaffold(body: Text('patient home')),
        ),
        GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productListProvider.overrideWith((_) async => <Product>[]),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    arriveByPush ? router.push('/shop') : router.go('/shop');
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the shop draws a Back', (tester) async {
    await pumpShop(tester, arriveByPush: true);

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('which returns to wherever the shop was opened from', (
    tester,
  ) async {
    final router = await pumpShop(tester, arriveByPush: true);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/patient/home');
    expect(find.text('patient home'), findsOneWidget);
  });

  testWidgets('and falls back to Home when there is nothing to pop', (
    tester,
  ) async {
    // The `ClinicListScreen` pattern, and the reason it exists: a deep link
    // or a `go` leaves the shop at the bottom of the stack, where `pop()`
    // throws. Home is a real destination; a crash is not.
    final router = await pumpShop(tester, arriveByPush: false);
    expect(router.canPop(), isFalse);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(router.state.uri.path, '/patient/home');
  });

  testWidgets('the therapist sheet does not offer it', (tester) async {
    // The shop is a patient surface. The therapist's three rows are their
    // schedule, their requests and their notifications, and adding a
    // storefront to them would be a new product decision rather than a fix
    // for an unreachable screen.
    // A modal sheet is capped at 9/16 of the viewport, and the therapist's
    // three rows do not fit that share of the 600dp default. A phone is
    // taller; this only restores a realistic one.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: TherapistNav(
              currentIndex: 0,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The therapist centre button wears the same calendar glyph as the
    // Schedule tab two slots to its left, so the bar draws that icon twice.
    // The white one on the pine disc is the centre action.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Icon && w.color == Colors.white,
        description: 'the centre action',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QUICK ACTION'), findsOneWidget);
    expect(find.text('Shop'), findsNothing);
  });

  group('on the real router', () {
    test('a patient can reach /shop', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      container.read(authProvider.notifier).state = const User(
        id: 'u1',
        name: 'Test',
        email: 'test@example.com',
        role: 'PATIENT',
        status: 'APPROVED',
      );

      final match = router.configuration.findMatch(Uri.parse('/shop'));
      final redirected = await router.configuration.redirect(
        _FakeContext(),
        match,
        redirectHistory: <RouteMatchList>[],
      );
      expect(redirected.uri.path, '/shop');
    });
  });
}

/// `redirect` only passes the context through to the route callbacks, and none
/// of the app's redirects touch it.
class _FakeContext extends Fake implements BuildContext {}
