import '../repositories/auth_repository.dart';
import '../repositories/email_verification_repository.dart';

class RequestEmailVerification {
  const RequestEmailVerification(this._repository);

  final EmailVerificationRepository _repository;

  Future<AuthResult<void>> call() => _repository.request();
}
