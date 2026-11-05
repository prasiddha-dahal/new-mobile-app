import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/core/error/failures.dart';
import 'package:sahayatri_care_connect/features/packages/data/datasources/package_api.dart';
import 'package:sahayatri_care_connect/features/packages/data/models/package_models.dart';
import 'package:sahayatri_care_connect/features/packages/data/repositories/package_repository_impl.dart';

/// A hand-rolled stand-in for the Retrofit client — the repository only needs
/// the five methods, and a fake keeps the test away from a live server (the
/// packages endpoints are not deployed yet).
class _FakeApi implements PackageApi {
  _FakeApi({
    this.packages = const [],
    this.purchases = const [],
    this.active,
    this.error,
  });

  final List<PackageDto> packages;
  final List<PackagePurchaseDto> purchases;
  final PackagePurchaseDto? active;

  /// Thrown by every call when set.
  final Object? error;

  PackagePurchaseRequestDto? lastPurchaseBody;
  String? lastPurchaseId;

  @override
  Future<PackageListDto> listPackages({int skip = 0, int limit = 100}) async {
    if (error != null) throw error!;
    return PackageListDto(packages: packages, total: packages.length);
  }

  @override
  Future<PackageDto> getPackage(String id) async {
    if (error != null) throw error!;
    return packages.firstWhere((p) => p.id == id);
  }

  @override
  Future<PackagePurchaseDto> purchasePackage(
    String id,
    PackagePurchaseRequestDto body,
  ) async {
    lastPurchaseId = id;
    lastPurchaseBody = body;
    if (error != null) throw error!;
    return active!;
  }

  @override
  Future<PackagePurchaseListDto> listMyPurchases() async {
    if (error != null) throw error!;
    return PackagePurchaseListDto(
      purchases: purchases,
      total: purchases.length,
    );
  }

  @override
  Future<PackagePurchaseDto> activePurchase() async {
    if (error != null) throw error!;
    return active!;
  }
}

DioException _http(int statusCode, {Object? body}) {
  final options = RequestOptions(path: '/packages/my-purchases/active');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: body,
    ),
  );
}

PackageDto _package({
  String id = 'package-1',
  String name = 'Stroke & Neuro Recovery',
  int sortOrder = 0,
  bool isActive = true,
}) => PackageDto(
  id: id,
  name: name,
  price: 24000,
  sortOrder: sortOrder,
  isActive: isActive,
);

const _purchaseDto = PackagePurchaseDto(
  id: 'purchase-1',
  packageId: 'package-1',
  packageName: 'Stroke & Neuro Recovery',
  sessionsTotal: 12,
  sessionsUsed: 2,
  status: 'ACTIVE',
);

void main() {
  group('getActivePurchase', () {
    test('404 is the empty state, not a failure', () async {
      final repo = PackageRepositoryImpl(
        _FakeApi(error: _http(404, body: {'detail': 'No active package found'})),
      );

      final result = await repo.getActivePurchase();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => _purchaseDto.toEntity()), isNull);
    });

    test('a 404 from the endpoint simply not existing reads the same', () async {
      // The packages branch is unmerged, so today every call 404s. A patient
      // must see "no active package", not an error box.
      final repo = PackageRepositoryImpl(_FakeApi(error: _http(404)));

      expect((await repo.getActivePurchase()).isRight(), isTrue);
    });

    test('a real active purchase comes back as an entity', () async {
      final repo = PackageRepositoryImpl(_FakeApi(active: _purchaseDto));

      final result = await repo.getActivePurchase();
      final purchase = result.getOrElse((_) => null);

      expect(purchase, isNotNull);
      expect(purchase!.packageName, 'Stroke & Neuro Recovery');
      expect(purchase.sessionsRemaining, 10);
    });

    test('any other status is still a failure', () async {
      final repo = PackageRepositoryImpl(_FakeApi(error: _http(500)));

      final result = await repo.getActivePurchase();

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ServerFailure>());
    });

    test('401 stays an auth failure rather than an empty state', () async {
      final repo = PackageRepositoryImpl(_FakeApi(error: _http(401)));

      final result = await repo.getActivePurchase();

      expect(result.getLeft().toNullable(), isA<UnauthorizedFailure>());
    });

    test('a connection error is a failure, not an empty state', () async {
      final repo = PackageRepositoryImpl(
        _FakeApi(
          error: DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final result = await repo.getActivePurchase();

      expect(result.getLeft().toNullable(), isA<ServerUnavailableFailure>());
    });

    test('isNoActivePackage only recognises a 404 response', () {
      expect(PackageRepositoryImpl.isNoActivePackage(_http(404)), isTrue);
      expect(PackageRepositoryImpl.isNoActivePackage(_http(400)), isFalse);
      expect(
        PackageRepositoryImpl.isNoActivePackage(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        isFalse,
      );
    });
  });

  group('listPackages', () {
    test('drops inactive rows and sorts by sortOrder', () async {
      final repo = PackageRepositoryImpl(
        _FakeApi(
          packages: [
            _package(id: 'c', name: 'Elderly Mobility', sortOrder: 3),
            _package(id: 'a', name: 'Stroke & Neuro', sortOrder: 1),
            _package(id: 'x', name: 'Retired plan', sortOrder: 0, isActive: false),
            _package(id: 'b', name: 'Sports Injury', sortOrder: 2),
          ],
        ),
      );

      final result = await repo.listPackages();
      final names = result
          .getOrElse((_) => [])
          .map((p) => p.name)
          .toList();

      expect(names, ['Stroke & Neuro', 'Sports Injury', 'Elderly Mobility']);
    });

    test('an empty catalogue is an empty success', () async {
      final result = await PackageRepositoryImpl(_FakeApi()).listPackages();

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => [_package().toEntity()]), isEmpty);
    });

    test('a missing catalogue endpoint surfaces as a retryable failure', () async {
      final repo = PackageRepositoryImpl(_FakeApi(error: _http(404)));

      final result = await repo.listPackages();

      expect(result.getLeft().toNullable(), isA<NotFoundFailure>());
    });
  });

  group('purchasePackage', () {
    test('sends the uppercased payment method to the right package', () async {
      final api = _FakeApi(active: _purchaseDto);

      final result = await PackageRepositoryImpl(api).purchasePackage(
        packageId: 'package-1',
        paymentMethod: 'esewa',
      );

      expect(api.lastPurchaseId, 'package-1');
      expect(api.lastPurchaseBody?.paymentMethod, 'ESEWA');
      expect(result.isRight(), isTrue);
    });

    test('403 for a non-patient keeps the backend wording', () async {
      final repo = PackageRepositoryImpl(
        _FakeApi(
          error: _http(403, body: {'detail': 'Only patients can purchase packages'}),
        ),
      );

      final failure = (await repo.purchasePackage(
        packageId: 'package-1',
        paymentMethod: 'CASH',
      )).getLeft().toNullable();

      expect(failure, isA<UnauthorizedFailure>());
      expect(failure!.message, 'Only patients can purchase packages');
    });

    test('400 for an existing active package keeps the backend wording', () async {
      final repo = PackageRepositoryImpl(
        _FakeApi(
          error: _http(400, body: {
            'detail': 'You already have an active package. '
                'Use your remaining sessions first.',
          }),
        ),
      );

      final failure = (await repo.purchasePackage(
        packageId: 'package-1',
        paymentMethod: 'CASH',
      )).getLeft().toNullable();

      expect(failure, isA<ValidationFailure>());
      expect(failure!.message, contains('already have an active package'));
    });
  });

  group('listMyPurchases', () {
    test('maps every row to an entity', () async {
      final repo = PackageRepositoryImpl(
        _FakeApi(purchases: const [_purchaseDto]),
      );

      final purchases = (await repo.listMyPurchases()).getOrElse((_) => []);

      expect(purchases, hasLength(1));
      expect(purchases.single.progressPercent, 17);
    });
  });
}
