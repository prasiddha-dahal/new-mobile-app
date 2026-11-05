import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/coverage_api.dart';
import '../../data/models/coverage_models.dart';

final coverageApiProvider = Provider<CoverageApi>((ref) {
  return CoverageApi(ref.watch(dioProvider));
});

Future<T> _guarded<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    throw mapDioErrorToFailure(e);
  } catch (e) {
    throw UnknownFailure(e.toString());
  }
}

/// The area chips.
final serviceAreasProvider = FutureProvider<List<ServiceAreaDto>>((ref) async {
  final result = await _guarded(() => ref.watch(coverageApiProvider).areas());
  return result.areas;
});

/// Which area the patient has selected. Null until the list loads and the
/// first area is chosen for them.
final selectedAreaProvider = StateProvider<String?>((_) => null);

/// Whether the screen is showing therapists or clinics.
enum CoverageTab { therapists, clinics }

final coverageTabProvider =
    StateProvider<CoverageTab>((_) => CoverageTab.therapists);

final coverageProvider = FutureProvider<CoverageDto>((ref) {
  final areaId = ref.watch(selectedAreaProvider);
  return _guarded(
    () => ref.watch(coverageApiProvider).coverage(areaId: areaId),
  );
});
