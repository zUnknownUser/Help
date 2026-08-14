import '../../../../core/result/result.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/password_reset_repository.dart';
import '../data_sources/password_reset_remote_data_source.dart';
import '../errors/auth_operation_guard.dart';

class PasswordResetRepositoryImpl implements PasswordResetRepository {
  const PasswordResetRepositoryImpl(this._remoteDataSource);

  final PasswordResetRemoteDataSource _remoteDataSource;

  @override
  Future<Result<void, AuthFailure>> requestPasswordReset(String email) {
    return guardAuthDataOperation(
      () => _remoteDataSource.requestPasswordReset(email),
    );
  }
}
