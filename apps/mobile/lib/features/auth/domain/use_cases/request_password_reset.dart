import '../../../../core/result/result.dart';
import '../failures/auth_failure.dart';
import '../repositories/password_reset_repository.dart';

class RequestPasswordReset {
  const RequestPasswordReset(this._repository);

  final PasswordResetRepository _repository;

  Future<Result<void, AuthFailure>> call(String email) {
    return _repository.requestPasswordReset(email.trim().toLowerCase());
  }
}
