import 'auth_repository.dart';

abstract interface class EmailVerificationRepository {
  Future<AuthResult<void>> request();
}
