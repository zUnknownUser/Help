import '../../../../core/result/result.dart';
import '../failures/auth_failure.dart';

abstract interface class PasswordResetRepository {
  Future<Result<void, AuthFailure>> requestPasswordReset(String email);
}
