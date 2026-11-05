import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/package_models.dart';

part 'package_api.g.dart';

/// Package catalogue and purchase endpoints.
///
/// `GET /packages` and `GET /packages/{id}` are public; everything else needs
/// the bearer token the auth interceptor attaches.
///
/// `/packages/my-purchases` is registered by `package_purchases_router`, which
/// `main.py` includes *before* `packages_router` — so it wins over the
/// `/packages/{package_id}` wildcard and does not need escaping here.
@RestApi()
abstract class PackageApi {
  factory PackageApi(Dio dio, {String baseUrl}) = _PackageApi;

  /// Pagination only — the endpoint has no tag filter and no search parameter.
  @GET('/packages')
  Future<PackageListDto> listPackages({
    @Query('skip') int skip = 0,
    @Query('limit') int limit = 100,
  });

  @GET('/packages/{id}')
  Future<PackageDto> getPackage(@Path('id') String id);

  /// 201 on success; 403 for a non-patient, 400 for an unavailable package or
  /// a patient who already holds an active one.
  @POST('/packages/{id}/purchase')
  Future<PackagePurchaseDto> purchasePackage(
    @Path('id') String id,
    @Body() PackagePurchaseRequestDto body,
  );

  @GET('/packages/my-purchases')
  Future<PackagePurchaseListDto> listMyPurchases();

  /// **404 means "no active package"**, not an error. The repository turns it
  /// into an empty success.
  @GET('/packages/my-purchases/active')
  Future<PackagePurchaseDto> activePurchase();
}
