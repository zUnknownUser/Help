import '../../../../core/result/result.dart';
import '../entities/auth_user.dart';
import '../failures/auth_failure.dart';

typedef AuthResult<T> = Result<T, AuthFailure>;

abstract interface class AuthRepository {
  Stream<AuthUser?> watchAuthState();

  Future<AuthResult<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthResult<AuthUser>> signInWithGoogle();

  Future<AuthResult<void>> signOut();
}
