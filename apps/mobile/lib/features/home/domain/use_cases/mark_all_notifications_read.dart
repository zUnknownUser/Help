import '../repositories/home_interaction_repository.dart';
import '../repositories/home_repository.dart';

class MarkAllNotificationsRead {
  const MarkAllNotificationsRead(this._repository);
  final HomeInteractionRepository _repository;

  Future<HomeOperationResult<void>> call() =>
      _repository.markAllNotificationsRead();
}
