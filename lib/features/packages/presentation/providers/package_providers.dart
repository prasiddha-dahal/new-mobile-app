import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/package_api.dart';
import '../../data/repositories/package_repository_impl.dart';
import '../../domain/entities/package_purchase.dart';
import '../../domain/entities/therapy_package.dart';
import '../../domain/repositories/package_repository.dart';
import '../../domain/usecases/package_usecases.dart';

final packageApiProvider = Provider<PackageApi>((ref) {
  return PackageApi(ref.watch(dioProvider));
});

final packageRepositoryProvider = Provider<PackageRepository>((ref) {
  return PackageRepositoryImpl(ref.watch(packageApiProvider));
});

final getPackagesUseCaseProvider = Provider<GetPackagesUseCase>(
  (ref) => GetPackagesUseCase(ref.watch(packageRepositoryProvider)),
);

final getMyPurchasesUseCaseProvider = Provider<GetMyPurchasesUseCase>(
  (ref) => GetMyPurchasesUseCase(ref.watch(packageRepositoryProvider)),
);

final getActivePackageUseCaseProvider = Provider<GetActivePackageUseCase>(
  (ref) => GetActivePackageUseCase(ref.watch(packageRepositoryProvider)),
);

final purchasePackageUseCaseProvider = Provider<PurchasePackageUseCase>(
  (ref) => PurchasePackageUseCase(ref.watch(packageRepositoryProvider)),
);

/// Unwraps an [AppResult] into an AsyncValue so screens get one
/// loading/error/data shape instead of hand-rolling each.
Future<T> _unwrap<T>(Future<AppResult<T>> future) async {
  final result = await future;
  return result.fold((failure) => throw failure, (value) => value);
}

/// The catalogue. Errors surface as a retryable [ErrorStateView]; while the
/// packages branch is unmerged this is a 404 → "Not found", which is honest.
final packageCatalogueProvider = FutureProvider<PackageCatalogue>((ref) async {
  final items = await _unwrap(ref.watch(getPackagesUseCaseProvider).call());
  return PackageCatalogue(items);
});

/// Free-text query for the catalogue screen. Applied client-side —
/// `GET /packages` has no `q` parameter.
final packageSearchProvider = StateProvider<String>((_) => '');

/// Selected tag chip, or null for "All". Chips are the real `tag` values, not
/// the mock's invented categories.
final packageTagFilterProvider = StateProvider<String?>((_) => null);

/// The catalogue narrowed by the current search and tag.
final filteredPackagesProvider = Provider<List<TherapyPackage>>((ref) {
  final catalogue = ref.watch(packageCatalogueProvider).valueOrNull;
  if (catalogue == null) return const [];
  return catalogue.filter(
    query: ref.watch(packageSearchProvider),
    tag: ref.watch(packageTagFilterProvider),
  );
});

/// The patient's active package, or null when there is none.
///
/// Never errors on a missing purchase: the repository maps the endpoint's 404
/// to an empty success.
final activePackageProvider = FutureProvider<PackagePurchase?>((ref) {
  return _unwrap(ref.watch(getActivePackageUseCaseProvider).call());
});

/// Every purchase, newest first — used for the "Past packages" history.
final myPackagePurchasesProvider = FutureProvider<List<PackagePurchase>>((ref) {
  return _unwrap(ref.watch(getMyPurchasesUseCaseProvider).call());
});

final packageActionsProvider = Provider<PackageActions>(PackageActions.new);

class PackageActions {
  PackageActions(this._ref);
  final Ref _ref;

  /// Buys a package and refreshes everything that shows one.
  Future<AppResult<PackagePurchase>> purchase({
    required String packageId,
    required String paymentMethod,
  }) async {
    final result = await _ref
        .read(purchasePackageUseCaseProvider)
        .call(packageId: packageId, paymentMethod: paymentMethod);

    if (result.isRight()) {
      _ref.invalidate(activePackageProvider);
      _ref.invalidate(myPackagePurchasesProvider);
    }
    return result;
  }

  /// Re-reads the purchase state — call after booking or cancelling a session,
  /// both of which move `sessionsUsed`.
  void refreshPurchases() {
    _ref.invalidate(activePackageProvider);
    _ref.invalidate(myPackagePurchasesProvider);
  }
}
