abstract interface class PasswordResetRemoteDataSource {
  Future<void> requestPasswordReset(String email);
}
