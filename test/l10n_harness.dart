/// Mounting a screen in a chosen language, for the per-area sweep tests.
///
/// The point of those tests is narrow and worth stating: they do not check
/// that the Nepali is *good* — no test can — but that the screen reads
/// **every** string it shows through `context.l10n`. A screen with one
/// literal left in it renders that literal in both languages, and the
/// assertion that a Nepali screen contains no English is what catches it.
///
/// Delegates come from `AppLocalizations.localizationsDelegates`, which is
/// what `SahayatriApp` installs, so a widget that reaches for
/// `MaterialLocalizations` or for locale-aware date symbols behaves here as
/// it does in the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/core/l10n/locale_provider.dart';
import 'package:sahayatri_care_connect/core/storage/preferences_storage.dart';

/// Pumps [child] under the app's real delegates at [locale].
///
/// Returns the container so a test can change the locale afterwards and pump
/// again, which is the other half of the check: the same widget, rebuilt,
/// must say something different.
/// [textScale] is the OS font-size slider. 1.6 is the setting the accessibility
/// audits on this project use, and it is where rows that fit in English at
/// 1.0 stop fitting.
Future<ProviderContainer> pumpLocalized(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
  double textScale = 1.0,
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      preferencesStorageProvider.overrideWithValue(
        InMemoryPreferencesStorage(),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await container.read(localeProvider.notifier).restored;
  await container.read(localeProvider.notifier).set(locale);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (_, ref, _) => MaterialApp(
          locale: ref.watch(localeProvider),
          // Null keeps the Material default, which is what every existing
          // caller was already getting. A golden wants the real one.
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Applied inside `MaterialApp` rather than over it, so the scale
          // survives the MediaQuery that `MaterialApp` builds for its own
          // navigator. Left null at 1.0 so the default path is untouched.
          builder: textScale == 1.0
              ? null
              : (_, widget) => MediaQuery.withClampedTextScaling(
                  minScaleFactor: textScale,
                  maxScaleFactor: textScale,
                  child: widget!,
                ),
          home: child,
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Switches the language and rebuilds, the way tapping the header toggle does.
Future<void> switchTo(
  WidgetTester tester,
  ProviderContainer container,
  Locale locale,
) async {
  await container.read(localeProvider.notifier).set(locale);
  await tester.pump();
}

/// Every piece of text the pumped tree is currently rendering.
///
/// Reads the widget tree rather than the render tree, so it sees a string
/// that is laid out off-screen or clipped — a literal does not stop being a
/// literal because it scrolled out of view.
List<String> renderedText(WidgetTester tester) {
  final out = <String>[];
  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      final data = widget.data;
      if (data != null && data.trim().isNotEmpty) {
        out.add(data);
      } else {
        final span = widget.textSpan;
        if (span != null) out.add(span.toPlainText());
      }
    } else if (widget is EditableText) {
      // A hint is not a Text: it lives in the InputDecoration.
      final hint = widget.controller.text;
      if (hint.trim().isNotEmpty) out.add(hint);
    }
  }
  return out;
}

/// Fails if any rendered string is one of [english].
///
/// Takes the exact English strings rather than sniffing for Latin script:
/// plenty of correct Nepali output contains Latin — `Rs`, `SAHA-XXXXXXXX`,
/// `eSewa`, an email address — and a heuristic that flagged those would be
/// turned off within a week.
void expectNoEnglish(WidgetTester tester, Iterable<String> english) {
  final rendered = renderedText(tester).map((s) => s.trim()).toSet();
  for (final phrase in english) {
    expect(
      rendered,
      isNot(contains(phrase.trim())),
      reason:
          '"$phrase" is still rendered with the app in Nepali, so that '
          'string is a hardcoded literal rather than an ARB key.',
    );
  }
}
