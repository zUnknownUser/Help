import '../repositories/auth_repository.dart';

class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<AuthResult<void>> call() => _repository.signOut();
}
