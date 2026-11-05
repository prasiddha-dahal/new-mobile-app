import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/core/l10n/l10n.dart';
import 'package:sahayatri_care_connect/features/clinics/domain/entities/clinic.dart';
import 'package:sahayatri_care_connect/features/clinics/domain/repositories/clinic_repository.dart';
import 'package:sahayatri_care_connect/features/clinics/presentation/providers/clinic_providers.dart';
import 'package:sahayatri_care_connect/features/clinics/presentation/screens/clinic_profile_screen.dart';

class _FakeClinicRepository implements ClinicRepository {
  @override
  Future<AppResult<List<Clinic>>> findClinics({
    String? search,
    String? city,
  }) async => Right([_clinic]);

  @override
  Future<AppResult<Clinic>> getClinic(String id) async => Right(_clinic);

  @override
  Future<AppResult<String>> bookVisit({
    required String clinicId,
    required String paymentMethod,
  }) async => const Left(NotImplementedFailure('POST /sessions'));
}

const _clinic = Clinic(
  id: 'clinic-1',
  name: 'Sahayatri Physio Centre',
  area: 'Jhamsikhel',
  city: 'Lalitpur',
  address: 'Jhamsikhel Road 12, Lalitpur',
  services: ['Physiotherapy'],
  phone: '+977 1 590 1234',
  hours: 'Sun–Fri · 7:00 – 19:00',
);

void main() {
  testWidgets('clinic details render above the booking action', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clinicRepositoryProvider.overrideWithValue(_FakeClinicRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClinicProfileScreen(clinicId: 'clinic-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sahayatri Physio Centre'), findsOneWidget);
    expect(find.text('Jhamsikhel Road 12, Lalitpur'), findsOneWidget);
    expect(find.text('Sun–Fri · 7:00 – 19:00'), findsOneWidget);
    expect(find.text('Continue to booking →'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
