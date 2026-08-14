import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class RegisterWithEmail {
  const RegisterWithEmail(this._repository);

  final AuthRepository _repository;

  Future<AuthResult<AuthUser>> call({
    required String displayName,
    required String email,
    required String password,
  }) {
    return _repository.signUpWithEmail(
      displayName: displayName.trim().replaceAll(RegExp(r'\s+'), ' '),
      email: email.trim(),
      password: password,
    );
  }
}
