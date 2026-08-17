import '../../../core/result/result.dart';
import '../domain/entities/provider_schedule.dart';
import '../domain/failures/scheduling_failure.dart';
import '../domain/repositories/scheduling_repository.dart';
import 'scheduling_remote_api.dart';

class SchedulingRepositoryImpl implements SchedulingRepository {
  const SchedulingRepositoryImpl(this._api);
  final SchedulingRemoteApi _api;

  @override
  Future<SchedulingResult<ProviderSchedule>> getProviderSchedule() =>
      _guard(_api.getSchedule);
  @override
  Future<SchedulingResult<ProviderSchedule>> saveProviderSchedule(
    ProviderSchedule schedule,
  ) => _guard(() => _api.saveSchedule(schedule));
  @override
  Future<SchedulingResult<ScheduleBlock>> addBlock(ScheduleBlockDraft draft) =>
      _guard(() => _api.addBlock(draft));
  @override
  Future<SchedulingResult<void>> deleteBlock(String id) =>
      _guard(() => _api.deleteBlock(id));
  @override
  Future<SchedulingResult<AvailableSlotPage>> getAvailableSlots(
    String serviceId, {
    String? cursor,
    int limit = 40,
  }) => _guard(() => _api.getSlots(serviceId, cursor: cursor, limit: limit));

  Future<SchedulingResult<T>> _guard<T>(Future<T> Function() operation) async {
    try {
      return Success(await operation());
    } on SchedulingApiException catch (error) {
      return FailureResult(
        SchedulingFailure(_type(error.statusCode), message: error.message),
      );
    } catch (error) {
      return FailureResult(
        SchedulingFailure(SchedulingFailureType.unknown, message: '$error'),
      );
    }
  }
}

SchedulingFailureType _type(int status) => switch (status) {
  0 => SchedulingFailureType.network,
  -1 => SchedulingFailureType.invalidResponse,
  400 => SchedulingFailureType.invalid,
  403 => SchedulingFailureType.forbidden,
  404 => SchedulingFailureType.notFound,
  409 => SchedulingFailureType.conflict,
  503 => SchedulingFailureType.unavailable,
  _ => SchedulingFailureType.unknown,
};
