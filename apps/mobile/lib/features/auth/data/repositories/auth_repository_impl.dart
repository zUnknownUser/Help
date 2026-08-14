import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../errors/auth_operation_guard.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Stream<AuthUser?> watchAuthState() {
    return _remoteDataSource.watchAuthState().map((model) => model?.toEntity());
  }

  @override
  Future<AuthResult<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) {
    return guardAuthDataOperation(
      () async => (await _remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      )).toEntity(),
    );
  }

  @override
  Future<AuthResult<AuthUser>> signInWithGoogle() {
    return guardAuthDataOperation(
      () async => (await _remoteDataSource.signInWithGoogle()).toEntity(),
    );
  }

  @override
  Future<AuthResult<void>> signOut() =>
      guardAuthDataOperation(_remoteDataSource.signOut);
}
