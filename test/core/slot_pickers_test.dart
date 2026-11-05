import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/widgets/password_field.dart';
import 'package:sahayatri_care_connect/core/widgets/slot_pickers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';

import '../l10n_harness.dart';

/// The date and time fields that replaced the day strip and the slot grid,
/// and the show/hide button on password fields.

String _key(DateTime d) => formatDateKey(d);

void main() {
  final today = DateTime.now();
  final d1 = DateTime(today.year, today.month, today.day + 1);
  final d3 = DateTime(today.year, today.month, today.day + 3);

  // Day 2 has nothing free, so the calendar must not offer it.
  final openTimes = {
    _key(d1): ['14:00', '09:00', '18:00'],
    _key(d3): ['10:00'],
  };

  group('sortedTimes', () {
    test('times sort as a clock does', () {
      expect(sortedTimes(['14:00', '09:00', '18:00']), [
        '09:00',
        '14:00',
        '18:00',
      ]);
    });
  });

  group('SlotPickerFields', () {
    late String? date;
    late String? time;

    Future<void> pump(WidgetTester tester, {String? startDate}) async {
      date = startDate;
      time = null;
      await pumpLocalized(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SlotPickerFields(
                openTimes: openTimes,
                date: date,
                time: time,
                onDate: (d) => setState(() {
                  date = d;
                  time = null;
                }),
                onTime: (t) => setState(() => time = t),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the chosen day and how many times it has free', (
      tester,
    ) async {
      await pump(tester, startDate: _key(d1));

      expect(find.textContaining('Tomorrow'), findsOneWidget);
      expect(find.text('3 times free'), findsOneWidget);
      expect(find.text('Pick a time'), findsOneWidget);
    });

    testWidgets('the time field is disabled until there is a day', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('slot-time')));
      await tester.pumpAndSettle();
      expect(find.text('MORNING'), findsNothing);
    });

    testWidgets('the time sheet groups the day by morning, afternoon, evening', (
      tester,
    ) async {
      await pump(tester, startDate: _key(d1));

      await tester.tap(find.byKey(const ValueKey('slot-time')));
      await tester.pumpAndSettle();

      expect(find.text('MORNING'), findsOneWidget);
      expect(find.text('AFTERNOON'), findsOneWidget);
      expect(find.text('EVENING'), findsOneWidget);

      await tester.tap(find.text('14:00'));
      await tester.pumpAndSettle();

      expect(time, '14:00');
      expect(find.text('14:00'), findsOneWidget, reason: 'shown in the field');
      expect(find.text('MORNING'), findsNothing, reason: 'the sheet closed');
    });

    testWidgets('the calendar offers only days with something free', (
      tester,
    ) async {
      await pump(tester, startDate: _key(d1));

      await tester.tap(find.byKey(const ValueKey('slot-date')));
      await tester.pumpAndSettle();
      expect(find.text('Days with free times'), findsOneWidget);

      // Day 3 is free: choosing it moves the field and clears the time.
      await tester.tap(find.text('${d3.day}').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(date, _key(d3));
      expect(find.text('1 time free'), findsOneWidget);
    });
  });

  group('PasswordField', () {
    testWidgets('starts hidden and toggles with the eye button', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'secret123');
      addTearDown(controller.dispose);
      await pumpLocalized(
        tester,
        Scaffold(body: PasswordField(controller: controller)),
      );

      EditableText field() =>
          tester.widget<EditableText>(find.byType(EditableText));

      expect(field().obscureText, isTrue);
      expect(find.byTooltip('Show password'), findsOneWidget);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(field().obscureText, isFalse);
      expect(field().autocorrect, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(field().obscureText, isTrue);
    });

    testWidgets('keeps the screen\'s own hint', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpLocalized(
        tester,
        Scaffold(
          body: PasswordField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Your password'),
          ),
        ),
      );
      expect(find.text('Your password'), findsOneWidget);
    });
  });
}
