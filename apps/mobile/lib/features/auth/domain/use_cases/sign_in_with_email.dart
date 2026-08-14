import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithEmail {
  const SignInWithEmail(this._repository);

  final AuthRepository _repository;

  Future<AuthResult<AuthUser>> call({
    required String email,
    required String password,
  }) {
    return _repository.signInWithEmail(email: email.trim(), password: password);
  }
}
