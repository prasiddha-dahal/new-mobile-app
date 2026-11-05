import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/error_mapper.dart';
import '../../domain/entities/working_hours.dart';
import '../../domain/repositories/therapist_availability_repository.dart';
import '../datasources/therapist_api.dart';
import '../models/therapist_models.dart';

class TherapistAvailabilityRepositoryImpl
    implements TherapistAvailabilityRepository {
  TherapistAvailabilityRepositoryImpl(this._api);

  final TherapistApi _api;

  /// How long the save is given before Dio calls it a timeout.
  ///
  /// The default is 15s and the worst realistic save measured 13.7s against a
  /// server on the same machine. Four minutes is not an expectation, it is
  /// headroom: the request is a long sequence of small writes and the only
  /// thing worse than a slow save here is a fast lie about one.
  static const saveTimeout = Duration(minutes: 4);

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
  Future<AppResult<WorkingHours>> getWorkingHours() => _guard(() async {
    final dto = await _api.getWorkingHours();
    return WorkingHours.fromWire(
      start: dto.start,
      end: dto.end,
      sessionMinutes: dto.sessionDuration,
      breakMinutes: dto.breakDuration,
      daysOfWeek: dto.daysOfWeek,
    );
  });

  @override
  Future<AppResult<WorkingHoursSaved>> saveWorkingHours(
    WorkingHours hours, {
    required DateTime from,
  }) => _guard(() async {
    final window = AvailabilityWindow.fromDate(from);

    final response = await _api.generateAvailability(
      GenerateAvailabilityDto(
        dateFrom: window.fromDate,
        dateTo: window.toDate,
        daysOfWeek: hours.dayWireValues,
        startTime: hours.startLabel,
        endTime: hours.endLabel,
        sessionDuration: hours.sessionMinutes,
        // Echoed back unchanged. Nothing on this screen edits it, and sending
        // a hardcoded 0 would reset a gap configured elsewhere and silently
        // change how the slot grid is stepped.
        breakDuration: hours.breakMinutes,
      ),
      Options(receiveTimeout: saveTimeout, sendTimeout: saveTimeout),
    );

    return WorkingHoursSaved(
      openedSlots: response.updated,
      fromDate: window.fromDate,
      toDate: window.toDate,
    );
  });
}
