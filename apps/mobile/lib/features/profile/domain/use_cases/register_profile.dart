import '../entities/user_profile.dart';
import '../entities/user_role.dart';
import '../repositories/profile_repository.dart';

class RegisterProfile {
  const RegisterProfile(this._repository);

  final ProfileRepository _repository;

  Future<ProfileResult<UserProfile>> call({
    required String displayName,
    required UserRole role,
  }) {
    return _repository.register(
      displayName: displayName.trim().replaceAll(RegExp(r'\s+'), ' '),
      role: role,
    );
  }
}
