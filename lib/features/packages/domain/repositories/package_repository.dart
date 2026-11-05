import '../../../../core/error/failures.dart';
import '../entities/package_purchase.dart';
import '../entities/therapy_package.dart';

abstract class PackageRepository {
  /// The active catalogue, sorted by `sortOrder`.
  ///
  /// `GET /packages` takes pagination only — no tag filter and no search
  /// parameter — so narrowing happens client-side in [PackageCatalogue].
  Future<AppResult<List<TherapyPackage>>> listPackages();

  Future<AppResult<TherapyPackage>> getPackage(String id);

  /// Buys [packageId]. Patients only: the API answers 403 for anyone else and
  /// 400 when the package is gone, inactive, or the patient already holds an
  /// active one.
  Future<AppResult<PackagePurchase>> purchasePackage({
    required String packageId,
    required String paymentMethod,
  });

  /// Every purchase the patient has made, newest first.
  Future<AppResult<List<PackagePurchase>>> listMyPurchases();

  /// The one active purchase, or `null` when there is none.
  ///
  /// `GET /packages/my-purchases/active` answers **404 for "no active
  /// package"**, which is an ordinary empty state rather than an error, so it
  /// is mapped to `Right(null)`. A 404 also arrives when the endpoint itself is
  /// missing (the API branch is unmerged) — both cases should render the same
  /// "no package yet" screen, so collapsing them is deliberate.
  Future<AppResult<PackagePurchase?>> getActivePurchase();
}
