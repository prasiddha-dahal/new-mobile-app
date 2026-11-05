import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/care_api.dart';
import '../../data/models/care_models.dart';

final careApiProvider = Provider<CareApi>((ref) {
  return CareApi(ref.watch(dioProvider));
});

Future<AppResult<T>> _guard<T>(Future<T> Function() action) async {
  try {
    return Right(await action());
  } on DioException catch (e) {
    return Left(mapDioErrorToFailure(e));
  } catch (e) {
    return Left(UnknownFailure(e.toString()));
  }
}

/// Documents shared by therapists, newest first.
final reportsProvider = FutureProvider<List<ReportDto>>((ref) async {
  final result = await _guard(() => ref.watch(careApiProvider).listReports());
  return result.fold(
    (failure) => throw failure,
    (reports) =>
        [...reports]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
});

/// The patient's referral code and share link.
final referralProvider = FutureProvider<ReferralDto>((ref) async {
  final result = await _guard(() => ref.watch(careApiProvider).getReferral());
  return result.fold((failure) => throw failure, (data) => data);
});

final careActionsProvider = Provider<CareActions>((ref) => CareActions(ref));

class CareActions {
  CareActions(this._ref);
  final Ref _ref;

  /// Files a complaint about a therapist.
  ///
  /// The endpoint takes the complainant from the request body rather than the
  /// token, so the signed-in user's id and name are attached here.
  Future<AppResult<void>> reportTherapist({
    required String therapistId,
    required String therapistName,
    required String category,
    required String description,
    int? rating,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      return const Left(UnauthorizedFailure('Please sign in again.'));
    }

    // The complaint model has no rating field, so a star rating is folded into
    // the description rather than dropped.
    final body = rating == null
        ? description
        : '$description\n\nExperience rating: $rating/5';

    return _guard(() async {
      await _ref
          .read(careApiProvider)
          .createComplaint(
            ComplaintCreateDto(
              type: 'Therapist',
              complainantId: user.id,
              complainantName: user.name,
              // The screen picks from the real directory now. This used to
              // send `againstId: ''`, which the API rejects outright
              // (min_length=1) -- so every report came back 422 and no
              // complaint was ever filed.
              againstId: therapistId,
              againstName: therapistName,
              category: category,
              description: body,
            ),
          );
    });
  }
}
