import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../patient/domain/entities/session.dart';
import '../../../patient/domain/entities/therapist.dart';
import '../../../patient/presentation/providers/patient_providers.dart'
    show formatDateKey, slotWindowDays;
import '../../data/datasources/therapist_api.dart';
import '../../data/models/therapist_models.dart';

final therapistApiProvider = Provider<TherapistApi>((ref) {
  return TherapistApi(ref.watch(dioProvider));
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

Future<T> _unwrap<T>(Future<AppResult<T>> future) async {
  final result = await future;
  return result.fold((failure) => throw failure, (value) => value);
}

final therapistDashboardProvider = FutureProvider<TherapistDashboardDto>((ref) {
  return _unwrap(_guard(() => ref.watch(therapistApiProvider).getDashboard()));
});

final therapistProfileProvider = FutureProvider<TherapistProfileDto>((ref) {
  return _unwrap(_guard(() => ref.watch(therapistApiProvider).getProfile()));
});

/// Every session assigned to this therapist.
final therapistSessionsProvider = FutureProvider<List<Session>>((ref) {
  return _unwrap(
    _guard(() async {
      final response = await ref.watch(therapistApiProvider).listSessions();
      return response.sessions.map((s) => s.toEntity()).toList();
    }),
  );
});

/// Search text on the My-patients screen.
final patientSearchProvider = StateProvider<String>((_) => '');

final myPatientsProvider = FutureProvider<List<MyPatientDto>>((ref) {
  final search = ref.watch(patientSearchProvider).trim();
  return _unwrap(
    _guard(() async {
      final response = await ref
          .watch(therapistApiProvider)
          .listMyPatients(search: search.isEmpty ? null : search);
      return response.patients;
    }),
  );
});

/// The therapist's own calendar for the next fortnight.
final ownSlotsProvider = FutureProvider<List<TherapistSlot>>((ref) {
  final now = DateTime.now();
  return _unwrap(
    _guard(() async {
      final response = await ref
          .watch(therapistApiProvider)
          .getOwnSlots(
            fromDate: formatDateKey(now),
            toDate: formatDateKey(
              now.add(const Duration(days: slotWindowDays)),
            ),
          );
      return response.slots.map((s) => s.toEntity()).toList();
    }),
  );
});

final transactionsProvider = FutureProvider<List<TransactionDto>>((ref) {
  return _unwrap(
    _guard(() async {
      final response = await ref.watch(therapistApiProvider).listTransactions();
      return response.transactions;
    }),
  );
});

/// The therapist's reviews, from `GET /therapists/me/reviews`.
final therapistReviewsProvider = FutureProvider<TherapistReviewsDto>((ref) {
  return _unwrap(_guard(() => ref.watch(therapistApiProvider).listMyReviews()));
});

final payoutsProvider = FutureProvider<List<PayoutDto>>((ref) {
  return _unwrap(
    _guard(() async {
      final response = await ref.watch(therapistApiProvider).listPayouts();
      return response.payouts;
    }),
  );
});

final blockRequestsProvider = FutureProvider<List<BlockRequestItemDto>>((ref) {
  return _unwrap(
    _guard(() => ref.watch(therapistApiProvider).listBlockRequests()),
  );
});

final therapistActionsProvider = Provider<TherapistActions>(
  (ref) => TherapistActions(ref),
);

class TherapistActions {
  TherapistActions(this._ref);
  final Ref _ref;

  TherapistApi get _api => _ref.read(therapistApiProvider);

  /// Accept, decline or complete a session — all are a status change on
  /// `PUT /sessions/{id}`.
  Future<AppResult<void>> setSessionStatus({
    required String sessionId,
    required SessionStatus status,
  }) async {
    final result = await _guard(() async {
      await _api.updateSession(
        sessionId,
        SessionUpdateDto(status: status.wireValue),
      );
    });
    result.match((_) {}, (_) => _invalidateSessionViews());
    return result;
  }

  Future<AppResult<void>> startSession(String sessionId) async {
    final result = await _guard(() async {
      await _api.startSession(sessionId);
    });
    result.match((_) {}, (_) => _invalidateSessionViews());
    return result;
  }

  Future<AppResult<void>> endSession(String sessionId) async {
    final result = await _guard(() async {
      await _api.endSession(sessionId);
    });
    result.match((_) {}, (_) => _invalidateSessionViews());
    return result;
  }

  /// Adds or replaces the therapist's notes on a session.
  Future<AppResult<void>> saveSessionNotes({
    required String sessionId,
    required String notes,
  }) async {
    final result = await _guard(() async {
      await _api.updateSession(sessionId, SessionUpdateDto(notes: notes));
    });
    result.match((_) {}, (_) => _invalidateSessionViews());
    return result;
  }

  Future<AppResult<void>> setSlot({
    required String date,
    required String time,
    required bool open,
  }) async {
    final result = await _guard(() async {
      await _api.setSlot(
        SlotUpdateDto(date: date, time: time, status: open ? 'open' : 'off'),
      );
    });
    result.match((_) {}, (_) => _ref.invalidate(ownSlotsProvider));
    return result;
  }

  /// Applies a weekly recurring pattern. Days are Sunday-indexed.
  Future<AppResult<int>> applyRecurring({
    required List<int> days,
    required List<String> sessions,
  }) async {
    final result = await _guard(() async {
      final response = await _api.applyRecurring(
        RecurringPatternCreateDto(days: days, sessions: sessions),
      );
      return response.affected;
    });
    result.match((_) {}, (_) => _ref.invalidate(ownSlotsProvider));
    return result;
  }

  /// Requests a day off. An admin approves it — the calendar is not blocked
  /// immediately.
  Future<AppResult<void>> requestDayOff({
    required String dateFrom,
    String? dateTo,
    required List<String> partsOfDay,
    required String reason,
  }) async {
    final result = await _guard(() async {
      await _api.requestBlock(
        BlockRequestDto(
          dateFrom: dateFrom,
          dateTo: dateTo,
          partsOfDay: partsOfDay,
          reason: reason,
        ),
      );
    });
    result.match((_) {}, (_) => _ref.invalidate(blockRequestsProvider));
    return result;
  }

  Future<AppResult<void>> updateProfile(TherapistProfileUpdateDto body) async {
    final result = await _guard(() async {
      await _api.updateProfile(body);
    });
    result.match((_) {}, (_) => _ref.invalidate(therapistProfileProvider));
    return result;
  }

  void _invalidateSessionViews() {
    _ref.invalidate(therapistSessionsProvider);
    _ref.invalidate(therapistDashboardProvider);
    _ref.invalidate(ownSlotsProvider);
  }
}
