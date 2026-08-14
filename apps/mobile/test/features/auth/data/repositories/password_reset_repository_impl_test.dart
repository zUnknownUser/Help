import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/data/data_sources/password_reset_remote_data_source.dart';
import 'package:help/features/auth/data/errors/auth_data_exception.dart';
import 'package:help/features/auth/data/repositories/password_reset_repository_impl.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:mocktail/mocktail.dart';

class _MockPasswordResetRemoteDataSource extends Mock
    implements PasswordResetRemoteDataSource {}

void main() {
  test('converte erro de rede em falha de domínio', () async {
    final remoteDataSource = _MockPasswordResetRemoteDataSource();
    when(
      () => remoteDataSource.requestPasswordReset(any()),
    ).thenThrow(const AuthDataException(AuthDataErrorCode.network));
    final repository = PasswordResetRepositoryImpl(remoteDataSource);

    final result = await repository.requestPasswordReset('user@example.com');

    expect(
      result,
      isA<FailureResult<void, AuthFailure>>().having(
        (value) => value.failure.type,
        'failure.type',
        AuthFailureType.network,
      ),
    );
  });
}
