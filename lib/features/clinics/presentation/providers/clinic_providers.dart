import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/clinic_api.dart';
import '../../data/repositories/clinic_repository_impl.dart';
import '../../domain/entities/clinic.dart';
import '../../domain/repositories/clinic_repository.dart';

final clinicApiProvider = Provider<ClinicApi>((ref) {
  return ClinicApi(ref.watch(dioProvider));
});

final clinicRepositoryProvider = Provider<ClinicRepository>((ref) {
  return ClinicRepositoryImpl(ref.watch(clinicApiProvider));
});

/// Unwraps an [AppResult] into an AsyncValue, so screens get one loading /
/// error / data shape to render instead of hand-rolling each.
Future<T> _unwrap<T>(Future<AppResult<T>> future) async {
  final result = await future;
  return result.fold((failure) => throw failure, (value) => value);
}

/// Search/filter state for the Find-a-clinic screen.
class ClinicQuery {
  const ClinicQuery({this.search = '', this.city});

  final String search;

  /// Null means "All" — the prototype's first chip.
  final String? city;

  ClinicQuery copyWith({
    String? search,
    String? city,
    bool clearCity = false,
  }) => ClinicQuery(
    search: search ?? this.search,
    city: clearCity ? null : (city ?? this.city),
  );

  @override
  bool operator ==(Object other) =>
      other is ClinicQuery && other.search == search && other.city == city;

  @override
  int get hashCode => Object.hash(search, city);
}

final clinicQueryProvider = StateProvider<ClinicQuery>(
  (_) => const ClinicQuery(),
);

/// Clinic list for the current [clinicQueryProvider].
final clinicListProvider = FutureProvider<List<Clinic>>((ref) {
  final query = ref.watch(clinicQueryProvider);
  return _unwrap(
    ref
        .watch(clinicRepositoryProvider)
        .findClinics(search: query.search, city: query.city),
  );
});

final clinicDetailProvider = FutureProvider.family<Clinic, String>((ref, id) {
  return _unwrap(ref.watch(clinicRepositoryProvider).getClinic(id));
});

final clinicActionsProvider = Provider<ClinicActions>((ref) {
  return ClinicActions(ref);
});

class ClinicActions {
  ClinicActions(this._ref);
  final Ref _ref;

  ClinicRepository get _repo => _ref.read(clinicRepositoryProvider);

  /// Nothing is invalidated on the way out because the call cannot succeed yet;
  /// see [ClinicRepository.bookVisit].
  Future<AppResult<String>> bookVisit({
    required String clinicId,
    required String paymentMethod,
  }) => _repo.bookVisit(clinicId: clinicId, paymentMethod: paymentMethod);
}
