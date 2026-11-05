// Smoke test: the app boots and renders its first route without throwing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sahayatri_care_connect/app.dart';

void main() {
  testWidgets('app boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SahayatriApp()),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
