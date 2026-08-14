import '../repositories/home_interaction_repository.dart';
import '../repositories/home_repository.dart';
import '../entities/home_location.dart';

class SaveHomeLocation {
  const SaveHomeLocation(this._repository);

  final HomeInteractionRepository _repository;

  Future<HomeOperationResult<void>> call(HomeLocation location) =>
      _repository.saveLocation(location);
}
