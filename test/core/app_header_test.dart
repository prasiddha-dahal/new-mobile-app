import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/core/l10n/locale_provider.dart';
import 'package:sahayatri_care_connect/core/storage/preferences_storage.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/core/widgets/app_header.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';

User _user(String name) => User(
  id: 'u1',
  name: name,
  email: 'aakar@example.com',
  role: 'PATIENT',
  status: 'APPROVED',
);

void main() {
  /// Mounts [AppHeader] the way a screen does: at the top of a Scaffold body,
  /// under the app's real localisation delegates, with the locale driven by
  /// `localeProvider` exactly as `SahayatriApp` drives it.
  ///
  /// [viewPadding] / [padding] are separate on purpose — see the inset test.
  Future<ProviderContainer> pumpHeader(
    WidgetTester tester, {
    User? user,
    Widget? leading,
    String? title,
    VoidCallback? onSearch,
    EdgeInsets viewPadding = EdgeInsets.zero,
    EdgeInsets padding = EdgeInsets.zero,
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        preferencesStorageProvider.overrideWithValue(
          InMemoryPreferencesStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (user != null) container.read(authProvider.notifier).state = user;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            viewPadding: viewPadding,
            padding: padding,
          ),
          child: Consumer(
            builder: (_, ref, _) => MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: ref.watch(localeProvider),
              home: Scaffold(
                body: Column(
                  children: [
                    AppHeader(
                      leading: leading,
                      title: title,
                      onSearch: onSearch,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// The rendered wordmark-and-name line.
  String identityLine(WidgetTester tester) {
    final text = tester.widget<Text>(find.byKey(AppHeader.identityKey));
    return text.textSpan!.toPlainText();
  }

  group('identity', () {
    testWidgets('shows the wordmark and the signed-in name', (tester) async {
      await pumpHeader(tester, user: _user('Aakar Sharma'));

      expect(identityLine(tester), 'Sahayatri  Aakar Sharma');
    });

    testWidgets('signed out: wordmark alone, no placeholder, no spinner', (
      tester,
    ) async {
      await pumpHeader(tester);

      expect(identityLine(tester), 'Sahayatri');
      // The two ways this degrades badly: printing the absent value, or
      // treating "nobody is signed in" as "still loading".
      expect(identityLine(tester), isNot(contains('null')));
      expect(find.textContaining('null', findRichText: true), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a user whose name came back blank is treated as no name', (
      tester,
    ) async {
      await pumpHeader(tester, user: _user('   '));

      expect(identityLine(tester), 'Sahayatri');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long name ellipsises instead of overflowing', (
      tester,
    ) async {
      const longName =
          'Aakar Bahadur Shrestha Sharma Adhikari Bhattarai Gurung Tamang';
      // Narrow phone: the line has to give way somewhere.
      await pumpHeader(
        tester,
        user: _user(longName),
        size: const Size(320, 640),
      );

      // An overflow surfaces as an exception during paint. This is the
      // assertion that actually catches the bug.
      expect(tester.takeException(), isNull);

      final identity = tester.widget<Text>(find.byKey(AppHeader.identityKey));
      expect(identity.overflow, TextOverflow.ellipsis);
      expect(identity.maxLines, 1);

      // It is clipped to the space it was given, not laid out at its natural
      // width and drawn over the controls beside it.
      final rendered = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(AppHeader.identityKey),
          matching: find.byType(RichText),
        ),
      );
      expect(rendered.size.width, lessThan(320));
      expect(rendered.didExceedMaxLines, isTrue);
    });
  });

  group('title and leading', () {
    testWidgets('title replaces the identity block', (tester) async {
      await pumpHeader(
        tester,
        user: _user('Aakar Sharma'),
        title: 'Therapy Packages',
      );

      expect(find.text('Therapy Packages'), findsOneWidget);
      expect(find.byKey(AppHeader.identityKey), findsNothing);
    });

    testWidgets('the global controls survive title mode', (tester) async {
      // The whole point of giving AppHeader a title is that a sub-page keeps
      // the language toggle instead of inventing a bare back bar.
      await pumpHeader(
        tester,
        title: 'Therapy Packages',
        leading: const AppHeaderBackButton(),
      );

      expect(find.byType(LanguageToggle), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('language toggle', () {
    testWidgets('tapping a segment switches the locale', (tester) async {
      final container = await pumpHeader(tester, user: _user('Aakar Sharma'));

      expect(container.read(localeProvider).languageCode, 'en');

      await tester.tap(find.text('नेपाली'));
      await tester.pumpAndSettle();

      expect(container.read(localeProvider).languageCode, 'ne');
    });

    testWidgets('the active segment is the one filled with brand green', (
      tester,
    ) async {
      await pumpHeader(tester, user: _user('Aakar Sharma'));

      BoxDecoration segment(String label) => tester
              .widget<AnimatedContainer>(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as BoxDecoration;

      expect(segment('EN').color, AppColors.pine);
      expect(segment('नेपाली').color, Colors.transparent);

      await tester.tap(find.text('नेपाली'));
      await tester.pumpAndSettle();

      expect(segment('नेपाली').color, AppColors.pine);
      expect(segment('EN').color, Colors.transparent);
    });

    testWidgets('switching locale re-renders the header in Nepali', (
      tester,
    ) async {
      await pumpHeader(tester, user: _user('Aakar Sharma'));

      await tester.tap(find.text('नेपाली'));
      await tester.pumpAndSettle();

      // The search button's accessible name comes from the ARB, so this
      // proves the delegates followed the toggle, not just the provider.
      final header = tester.element(find.byType(AppHeader));
      expect(header.l10n.searchTooltip, 'खोज्नुहोस्');
    });
  });

  group('search', () {
    testWidgets('tapping search fires the callback', (tester) async {
      var taps = 0;
      await pumpHeader(
        tester,
        user: _user('Aakar Sharma'),
        onSearch: () => taps++,
      );

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('the default handler does not require a caller or a router', (
      tester,
    ) async {
      // No onSearch, no GoRouter above it. The default must be a no-op here
      // rather than an exception, because the header is shared chrome.
      await pumpHeader(tester, user: _user('Aakar Sharma'));

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('top inset', () {
    testWidgets('clears the status bar even when an ancestor consumed the '
        'padding', (tester) async {
      // The exact shape of the bug nav_bars.dart was fixed for, at the other
      // end of the screen: `padding` is zero because something above already
      // consumed it, while `viewPadding` still reports the real status bar.
      // A SafeArea here would resolve to zero and put the wordmark under the
      // notch.
      await pumpHeader(
        tester,
        user: _user('Aakar Sharma'),
        viewPadding: const EdgeInsets.only(top: 48),
        padding: EdgeInsets.zero,
      );

      final headerTop = tester.getRect(find.byType(AppHeader)).top;
      final wordmarkTop = tester.getRect(find.byKey(AppHeader.identityKey)).top;

      expect(wordmarkTop - headerTop, greaterThanOrEqualTo(48));
    });

    testWidgets('reserves nothing when there is no status bar', (tester) async {
      await pumpHeader(tester, user: _user('Aakar Sharma'));

      final height = tester.getRect(find.byType(AppHeader)).height;
      expect(height, AppHeader.barHeight);
    });

    testWidgets('grows with the inset rather than using a fixed height', (
      tester,
    ) async {
      await pumpHeader(tester, user: _user('Aakar Sharma'));
      final short = tester.getRect(find.byType(AppHeader)).height;

      await pumpHeader(
        tester,
        user: _user('Aakar Sharma'),
        viewPadding: const EdgeInsets.only(top: 48),
      );
      final tall = tester.getRect(find.byType(AppHeader)).height;

      expect(tall - short, closeTo(48, 0.5));
    });

    testWidgets('does not pad the status bar twice', (tester) async {
      // AppHeader owns the inset, so it strips `padding` from its subtree. A
      // nested SafeArea inside it must therefore add nothing.
      await pumpHeader(
        tester,
        user: _user('Aakar Sharma'),
        viewPadding: const EdgeInsets.only(top: 48),
        padding: const EdgeInsets.only(top: 48),
      );

      final headerTop = tester.getRect(find.byType(AppHeader)).top;
      final wordmarkTop = tester.getRect(find.byKey(AppHeader.identityKey)).top;

      expect(wordmarkTop - headerTop, lessThan(96));
    });
  });
}
