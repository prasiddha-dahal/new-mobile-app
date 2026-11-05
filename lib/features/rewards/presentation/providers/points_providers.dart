import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/points_api.dart';
import '../../data/models/points_models.dart';

final pointsApiProvider = Provider<PointsApi>((ref) {
  return PointsApi(ref.watch(dioProvider));
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

final pointBalanceProvider = FutureProvider<PointBalanceDto>((ref) {
  return _guarded(() => ref.watch(pointsApiProvider).balance());
});

final pointTransactionsProvider =
    FutureProvider<PointTransactionListDto>((ref) {
  return _guarded(() => ref.watch(pointsApiProvider).transactions());
});

final referralSummaryProvider = FutureProvider<ReferralSummaryDto>((ref) {
  return _guarded(() => ref.watch(pointsApiProvider).referrals());
});

/// Spendable balance for the booking screen; 0 while loading or on error so
/// the checkout never offers points it cannot prove the user has.
final spendablePointsProvider = Provider<int>((ref) {
  return ref.watch(pointBalanceProvider).maybeWhen(
        data: (b) => b.balance,
        orElse: () => 0,
      );
});

final pointsActionsProvider = Provider<PointsActions>((ref) => PointsActions(ref));

class PointsActions {
  PointsActions(this._ref);
  final Ref _ref;

  /// Spends points against a booking that already exists.
  Future<AppResult<ApplyPointsResponseDto>> applyToSession({
    required String sessionId,
    required int points,
  }) async {
    try {
      final result = await _ref.read(pointsApiProvider).applyToSession(
            sessionId,
            ApplyPointsRequestDto(points: points),
          );
      _refresh();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioErrorToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  void _refresh() {
    _ref.invalidate(pointBalanceProvider);
    _ref.invalidate(pointTransactionsProvider);
  }
}
