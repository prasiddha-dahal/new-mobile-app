import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../domain/entities/package_purchase.dart';
import '../../domain/entities/therapy_package.dart';
import '../../domain/repositories/package_repository.dart';
import '../datasources/package_api.dart';
import '../models/package_models.dart';

class PackageRepositoryImpl implements PackageRepository {
  PackageRepositoryImpl(this._api);

  final PackageApi _api;

  Future<AppResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<AppResult<List<TherapyPackage>>> listPackages() => _guard(() async {
    final response = await _api.listPackages();
    final items = response.packages
        .map((p) => p.toEntity())
        .where((p) => p.isActive)
        .toList();
    // `GET /packages` returns rows in insertion order; `sortOrder` is the field
    // the admin actually curates, so honour it here rather than in the widget.
    items.sort((a, b) {
      final bySort = a.sortOrder.compareTo(b.sortOrder);
      return bySort != 0 ? bySort : a.name.compareTo(b.name);
    });
    return items;
  });

  @override
  Future<AppResult<TherapyPackage>> getPackage(String id) =>
      _guard(() async => (await _api.getPackage(id)).toEntity());

  @override
  Future<AppResult<PackagePurchase>> purchasePackage({
    required String packageId,
    required String paymentMethod,
  }) => _guard(() async {
    final dto = await _api.purchasePackage(
      packageId,
      PackagePurchaseRequestDto(paymentMethod: paymentMethod.toUpperCase()),
    );
    return dto.toEntity();
  });

  @override
  Future<AppResult<List<PackagePurchase>>> listMyPurchases() =>
      _guard(() async {
        final response = await _api.listMyPurchases();
        return response.purchases.map((p) => p.toEntity()).toList();
      });

  @override
  Future<AppResult<PackagePurchase?>> getActivePurchase() async {
    try {
      return Right((await _api.activePurchase()).toEntity());
    } on DioException catch (e) {
      // 404 is the documented answer for "this patient has no active package".
      // It is an empty state, not a failure — surfacing it as one would put a
      // red error box on the home screen of every patient who has never bought
      // a package. The same 404 arrives while the packages branch is unmerged
      // and the route does not exist at all, which should read identically.
      if (isNoActivePackage(e)) return const Right(null);
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  /// Whether [error] is the "no active package" 404 rather than a real fault.
  ///
  /// Exposed for tests: the mapping is the one piece of behaviour that makes
  /// the empty state work, and it is worth pinning down.
  static bool isNoActivePackage(DioException error) =>
      error.type == DioExceptionType.badResponse &&
      error.response?.statusCode == 404;
}
