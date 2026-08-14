import '../repositories/home_interaction_repository.dart';
import '../repositories/home_repository.dart';

class MarkNotificationRead {
  const MarkNotificationRead(this._repository);

  final HomeInteractionRepository _repository;

  Future<HomeOperationResult<void>> call(String id) =>
      _repository.markNotificationRead(id);
}
