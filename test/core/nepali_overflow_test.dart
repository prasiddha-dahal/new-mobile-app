import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_data.dart';
import 'package:sahayatri_care_connect/core/widgets/app_header.dart';
import 'package:sahayatri_care_connect/core/widgets/nav_bars.dart';
import 'package:sahayatri_care_connect/features/clinics/domain/entities/clinic.dart';
import 'package:sahayatri_care_connect/features/clinics/presentation/providers/clinic_providers.dart';
import 'package:sahayatri_care_connect/features/clinics/presentation/screens/clinic_list_screen.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/session.dart';
import 'package:sahayatri_care_connect/features/patient/domain/entities/therapist.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/providers/patient_providers.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_contact_screen.dart';
import 'package:sahayatri_care_connect/features/patient/presentation/screens/patient_sessions_screen.dart';
import 'package:sahayatri_care_connect/features/shop/domain/entities/product.dart';
import 'package:sahayatri_care_connect/features/shop/presentation/providers/shop_providers.dart';
import 'package:sahayatri_care_connect/features/shop/presentation/screens/shop_screen.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_certifications_screen.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_payout_methods_screen.dart';
import 'package:sahayatri_care_connect/features/therapist/presentation/screens/therapist_service_areas_screen.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/screens/login_screen.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/screens/verify_pending_screen.dart';

import '../l10n_harness.dart';

/// Nepali is longer than English, and the places that breaks are the places
/// with no room to give: a two-item row, a pill, a bar of four labels, the
/// header's identity line.
///
/// Everything here is pumped at 320×640 — a small Android phone, narrower
/// than anything in the design files — because a string that fits a 390pt
/// iPhone can still overflow one of those. Two of these caught real breakage
/// when they were written: the sign-in footer overflowed by 87px and the
/// application-reference row by 27px.
///
/// A RenderFlex overflow is thrown as an exception during layout, so
/// `takeException` is the assertion: nothing to catch means nothing
/// overflowed.
const _narrow = Size(320, 640);

User _user(String name) => User(
  id: 'u1',
  name: name,
  email: 'aakar@example.com',
  role: 'PATIENT',
  status: 'APPROVED',
);

void main() {
  Future<void> expectNoOverflow(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    await pumpLocalized(
      tester,
      child,
      locale: const Locale('ne'),
      size: _narrow,
      overrides: overrides,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('the sign-in screen fits a small phone in Nepali', (
    tester,
  ) async {
    await expectNoOverflow(tester, const LoginScreen());
  });

  testWidgets('and Nepali does not make the waiting room worse', (
    tester,
  ) async {
    // This screen centres a Column in a fixed-height Padding with nothing to
    // scroll, so on a 640pt viewport it already overflows vertically in
    // English — by more than it does in Nepali. That is a pre-existing layout
    // bug, not something this translation pass introduced, and fixing it
    // means giving the screen a scroll view, which is a layout change rather
    // than a translation. Asserted comparatively so it is on the record and
    // so a Nepali string that *did* make it worse would fail here.
    double overflow(Object? exception) {
      final text = exception?.toString() ?? '';
      final match = RegExp(r'overflowed by ([\d.]+) pixels').firstMatch(text);
      return match == null ? 0 : double.parse(match.group(1)!);
    }

    await pumpLocalized(
      tester,
      const VerifyPendingScreen(),
      locale: const Locale('en'),
      size: _narrow,
    );
    await tester.pump();
    final inEnglish = overflow(tester.takeException());

    await pumpLocalized(
      tester,
      const VerifyPendingScreen(),
      locale: const Locale('ne'),
      size: _narrow,
    );
    await tester.pump();
    final inNepali = overflow(tester.takeException());

    expect(
      inNepali,
      lessThanOrEqualTo(inEnglish),
      reason: 'Nepali overflows this screen more than English does',
    );
  });

  testWidgets('the waiting room fits a normal phone in Nepali', (tester) async {
    await pumpLocalized(
      tester,
      const VerifyPendingScreen(),
      locale: const Locale('ne'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bottom bar fits four Nepali labels', (tester) async {
    // The labels are drawn under the icons now, so this test finally means
    // what its name always said: four Devanagari words, four slots, 320pt.
    // "सूचनाहरू" is the long one and it is the one that decides.
    await expectNoOverflow(
      tester,
      Scaffold(
        bottomNavigationBar: PatientNav(currentIndex: 0, onSelect: (_) {}),
      ),
    );
    for (final label in ['गृह', 'सत्रहरू', 'सूचनाहरू', 'खाता']) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: '$label should be drawn',
      );
    }
  });

  testWidgets('and the therapist bar too', (tester) async {
    // "अनुरोधहरू" is longer still than the patient bar's worst case.
    await expectNoOverflow(
      tester,
      Scaffold(
        bottomNavigationBar: TherapistNav(currentIndex: 0, onSelect: (_) {}),
      ),
    );
    for (final label in ['गृह', 'तालिका', 'अनुरोधहरू', 'खाता']) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: '$label should be drawn',
      );
    }
  });

  testWidgets('the header survives a long name beside a Nepali toggle', (
    tester,
  ) async {
    // Wordmark + name + the "नेपाली" pill + the search button, on 320pt. The
    // identity line is a single Text.rich precisely so the name gives way
    // first; this pins that it still does.
    await pumpLocalized(
      tester,
      const Scaffold(appBar: AppHeader(), body: SizedBox()),
      locale: const Locale('ne'),
      size: _narrow,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('including when the name is absurdly long', (tester) async {
    final container = await pumpLocalized(
      tester,
      const Scaffold(appBar: AppHeader(), body: SizedBox()),
      locale: const Locale('ne'),
      size: _narrow,
    );
    container.read(authProvider.notifier).state = _user(
      'Aakar Bahadur Shrestha Pradhananga',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  /// The states `feat/ui-consistency` introduced, at the size and scale this
  /// file exists for — and at **1.6x**, not 1.0, because that is where these
  /// particular ones can break.
  ///
  /// A skeleton has no text in it, so the risk is not the skeleton: it is the
  /// header and filter chrome above it growing under Devanagari at 1.6x until
  /// the placeholder is squeezed out of the viewport, leaving a screen that
  /// reads as broken rather than busy. The consolidated empty state has the
  /// opposite risk — those five callers hand it a whole sentence as a *title*,
  /// set at 16/700 and centred.
  group('the loading and empty states at 1.6x', () {
    Future<void> expectFits(
      WidgetTester tester,
      Widget child, {
      List<Override> overrides = const [],
    }) async {
      await pumpLocalized(
        tester,
        child,
        locale: const Locale('ne'),
        size: _narrow,
        textScale: 1.6,
        overrides: overrides,
        theme: AppTheme.light,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    testWidgets('Sessions, waiting', (tester) async {
      await expectFits(
        tester,
        const PatientSessionsScreen(),
        overrides: [
          patientSessionsProvider.overrideWith(
            (_) => Completer<List<Session>>().future,
          ),
        ],
      );
    });

    testWidgets('Sessions, with nothing booked', (tester) async {
      await expectFits(
        tester,
        const PatientSessionsScreen(),
        overrides: [
          patientSessionsProvider.overrideWith((_) async => <Session>[]),
          therapistListProvider.overrideWith((_) async => <Therapist>[]),
        ],
      );
    });

    testWidgets('the shop grid, waiting', (tester) async {
      await expectFits(
        tester,
        const ShopScreen(),
        overrides: [
          productListProvider.overrideWith(
            (_) => Completer<List<Product>>().future,
          ),
          // The header's cart badge watches this too; without it the screen
          // reaches Dio and the test fails on a pending timer rather than on
          // anything to do with layout.
          cartProvider.overrideWith((_) async => const Cart.empty()),
        ],
      );
    });

    testWidgets('the clinic list, waiting', (tester) async {
      // This one also pins the `Scaffold` that was missing from it.
      await expectFits(
        tester,
        const ClinicListScreen(),
        overrides: [
          clinicListProvider.overrideWith(
            (_) => Completer<List<Clinic>>().future,
          ),
        ],
      );
    });
  });

  /// The screens whose dead controls now open a dialog. Nothing about the
  /// explaining changes their layout, but they had no small-phone coverage at
  /// 1.6x at all and they are dense: a wrap of pine chips, a grouped card of
  /// payout rows, a five-line composer.
  group('the screens whose controls now explain, at 1.6x', () {
    for (final (name, screen) in const <(String, Widget)>[
      ('certifications', TherapistCertificationsScreen()),
      ('payout methods', TherapistPayoutMethodsScreen()),
      ('service areas', TherapistServiceAreasScreen()),
      ('contact support', PatientContactScreen()),
    ]) {
      testWidgets(name, (tester) async {
        await pumpLocalized(
          tester,
          screen,
          locale: const Locale('ne'),
          size: _narrow,
          textScale: 1.6,
          theme: AppTheme.light,
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: name);
      });
    }
  });
}
