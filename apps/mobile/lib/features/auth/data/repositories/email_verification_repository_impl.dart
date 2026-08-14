import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/email_verification_repository.dart';
import '../data_sources/email_verification_remote_data_source.dart';
import '../errors/auth_operation_guard.dart';

class EmailVerificationRepositoryImpl implements EmailVerificationRepository {
  const EmailVerificationRepositoryImpl(this._remote);

  final EmailVerificationRemoteDataSource _remote;

  @override
  Future<AuthResult<void>> request() => guardAuthDataOperation(_remote.request);
}
