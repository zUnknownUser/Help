import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class GetCurrentProfile {
  const GetCurrentProfile(this._repository);

  final ProfileRepository _repository;

  Future<ProfileResult<UserProfile>> call() => _repository.getCurrent();
}
