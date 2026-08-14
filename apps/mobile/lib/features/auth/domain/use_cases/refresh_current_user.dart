import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class RefreshCurrentUser {
  const RefreshCurrentUser(this._repository);

  final AuthRepository _repository;

  Future<AuthResult<AuthUser>> call() => _repository.refreshCurrentUser();
}
