import '../models/auth_user_model.dart';

abstract interface class AuthRemoteDataSource {
  Stream<AuthUserModel?> watchAuthState();

  Future<AuthUserModel> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUserModel> signInWithGoogle();

  Future<void> signOut();
}
