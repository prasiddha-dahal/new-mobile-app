import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/features/clinics/domain/entities/clinic.dart';
import 'package:sahayatri_care_connect/features/clinics/domain/repositories/clinic_repository.dart';
import 'package:sahayatri_care_connect/features/clinics/presentation/providers/clinic_providers.dart';
import 'package:sahayatri_care_connect/features/clinics/presentation/screens/clinic_booking_screen.dart';

/// There was no test file for the clinics feature at all. This one covers the
/// line that will run the hour the booking endpoint lands.
///
/// `_confirm` sent the caller to `/clinics/booked?ref=$reference`. That route
/// reads `clinic`, `address`, `hours`, `date` and `time`, and has never read
/// `ref` — so the receipt would have opened with a fallback title and an em
/// dash where the address goes. Nobody would have noticed, because `bookVisit`
/// always fails today: `Session` has no `clinicId`, so there is nowhere to
/// record the visit.
class _FakeClinicRepository implements ClinicRepository {
  _FakeClinicRepository({required this.clinic, required this.booking});

  final Clinic clinic;
  final AppResult<String> booking;

  @override
  Future<AppResult<List<Clinic>>> findClinics({
    String? search,
    String? city,
  }) async => Right([clinic]);

  @override
  Future<AppResult<Clinic>> getClinic(String id) async => Right(clinic);

  @override
  Future<AppResult<String>> bookVisit({
    required String clinicId,
    required String paymentMethod,
  }) async => booking;
}

const _clinic = Clinic(
  id: 'clinic-1',
  name: 'Sahayatri Physio Centre — Jhamsikhel',
  area: 'Jhamsikhel',
  city: 'Lalitpur',
  address: 'Jhamsikhel Road 12, Lalitpur',
  services: ['Physiotherapy'],
  phone: '+977 1 590 1234',
  hours: 'Sun–Fri · 7:00 – 19:00',
);

void main() {
  Future<GoRouter> pumpBooking(
    WidgetTester tester, {
    required AppResult<String> booking,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/clinics/clinic-1/book',
      routes: [
        GoRoute(
          path: '/clinics/:id/book',
          builder: (_, state) =>
              ClinicBookingScreen(clinicId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/clinics/booked',
          builder: (_, _) => const Scaffold(body: Text('receipt')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clinicRepositoryProvider.overrideWithValue(
            _FakeClinicRepository(clinic: _clinic, booking: booking),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a successful booking carries what the receipt actually reads', (
    tester,
  ) async {
    final router = await pumpBooking(tester, booking: const Right('BK-1'));

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/clinics/booked');
    expect(uri.queryParameters['clinic'], _clinic.name);
    expect(uri.queryParameters['address'], _clinic.address);
    expect(
      uri.queryParameters.containsKey('ref'),
      isFalse,
      reason:
          'The receipt route has no `ref` parameter, so sending one sent '
          'nothing at all.',
    );
    expect(find.text('receipt'), findsOneWidget);
  });

  testWidgets('and a failed one explains rather than routing', (tester) async {
    // Which is what happens today, and will keep happening until `Session`
    // carries a `clinicId`.
    final router = await pumpBooking(
      tester,
      booking: const Left(NotImplementedFailure('POST /sessions (clinic)')),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/clinics/clinic-1/book',
    );
  });
}
