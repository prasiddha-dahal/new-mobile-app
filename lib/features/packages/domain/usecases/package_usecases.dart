import '../../../../core/error/failures.dart';
import '../entities/package_purchase.dart';
import '../entities/therapy_package.dart';
import '../repositories/package_repository.dart';

class GetPackagesUseCase {
  const GetPackagesUseCase(this._repository);
  final PackageRepository _repository;

  Future<AppResult<List<TherapyPackage>>> call() => _repository.listPackages();
}

class GetPackageUseCase {
  const GetPackageUseCase(this._repository);
  final PackageRepository _repository;

  Future<AppResult<TherapyPackage>> call(String id) =>
      _repository.getPackage(id);
}

class PurchasePackageUseCase {
  const PurchasePackageUseCase(this._repository);
  final PackageRepository _repository;

  Future<AppResult<PackagePurchase>> call({
    required String packageId,
    required String paymentMethod,
  }) => _repository.purchasePackage(
    packageId: packageId,
    paymentMethod: paymentMethod,
  );
}

class GetMyPurchasesUseCase {
  const GetMyPurchasesUseCase(this._repository);
  final PackageRepository _repository;

  Future<AppResult<List<PackagePurchase>>> call() =>
      _repository.listMyPurchases();
}

/// Resolves to `null` when the patient holds no active package.
class GetActivePackageUseCase {
  const GetActivePackageUseCase(this._repository);
  final PackageRepository _repository;

  Future<AppResult<PackagePurchase?>> call() => _repository.getActivePurchase();
}
