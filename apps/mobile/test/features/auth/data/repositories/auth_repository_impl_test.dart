import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:help/features/auth/data/errors/auth_data_exception.dart';
import 'package:help/features/auth/data/models/auth_user_model.dart';
import 'package:help/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:help/features/auth/domain/failures/auth_failure.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late AuthRemoteDataSource remoteDataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    remoteDataSource = _MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(remoteDataSource);
  });

  test(
    'converte o model remoto em entidade ao autenticar por e-mail',
    () async {
      const model = AuthUserModel(id: '1', email: 'user@email.com');
      when(
        () => remoteDataSource.signInWithEmail(
          email: 'user@email.com',
          password: '123456',
        ),
      ).thenAnswer((_) async => model);

      final result = await repository.signInWithEmail(
        email: 'user@email.com',
        password: '123456',
      );

      expect(result, isA<Success>());
      expect((result as Success).value, equals(model.toEntity()));
    },
  );

  test('cria conta por e-mail e converte o usuário', () async {
    const model = AuthUserModel(
      id: '1',
      email: 'user@email.com',
      displayName: 'Maria Silva',
    );
    when(
      () => remoteDataSource.signUpWithEmail(
        displayName: 'Maria Silva',
        email: 'user@email.com',
        password: '12345678',
      ),
    ).thenAnswer((_) async => model);

    final result = await repository.signUpWithEmail(
      displayName: 'Maria Silva',
      email: 'user@email.com',
      password: '12345678',
    );

    expect(result, isA<Success>());
    expect((result as Success).value, equals(model.toEntity()));
  });

  test('recarrega o usuário autenticado', () async {
    const model = AuthUserModel(
      id: '1',
      email: 'user@email.com',
      emailVerified: true,
    );
    when(remoteDataSource.refreshCurrentUser).thenAnswer((_) async => model);

    final result = await repository.refreshCurrentUser();

    expect(result, isA<Success>());
    expect((result as Success).value, equals(model.toEntity()));
  });

  test('traduz credenciais inválidas para falha de domínio', () async {
    when(
      () => remoteDataSource.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthDataException(AuthDataErrorCode.invalidCredentials));

    final result = await repository.signInWithEmail(
      email: 'user@email.com',
      password: 'wrong',
    );

    expect(result, isA<FailureResult>());
    expect(
      (result as FailureResult).failure,
      const AuthFailure(AuthFailureType.invalidCredentials),
    );
  });

  test('converte o stream de sessão remota em entidades', () async {
    const model = AuthUserModel(id: '1', email: 'user@email.com');
    when(
      remoteDataSource.watchAuthState,
    ).thenAnswer((_) => Stream.value(model));

    await expectLater(repository.watchAuthState(), emits(model.toEntity()));
  });

  test('encerra a sessão e devolve sucesso', () async {
    when(remoteDataSource.signOut).thenAnswer((_) async {});

    final result = await repository.signOut();

    expect(result, isA<Success<void, AuthFailure>>());
    verify(remoteDataSource.signOut).called(1);
  });
}
