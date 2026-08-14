import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/data/data_sources/home_remote_data_source.dart';
import 'package:help/features/home/data/errors/home_data_exception.dart';
import 'package:help/features/home/data/models/home_content_model.dart';
import 'package:help/features/home/data/repositories/home_repository_impl.dart';
import 'package:help/features/home/domain/failures/home_failure.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeRemoteDataSource extends Mock implements HomeRemoteDataSource {}

void main() {
  const model = HomeContentModel.empty();

  test('devolve a resposta recebida da API', () async {
    final remote = _MockHomeRemoteDataSource();
    when(remote.fetchHome).thenAnswer((_) async => model);
    final repository = HomeRepositoryImpl(remote: remote);

    final result = await repository.getHome();

    expect(result.isSuccess, isTrue);
    verify(remote.fetchHome).called(1);
  });

  test('expõe falha de domínio quando a API não está disponível', () async {
    final remote = _MockHomeRemoteDataSource();
    when(
      remote.fetchHome,
    ).thenThrow(const HomeDataException(HomeDataErrorCode.network));
    final repository = HomeRepositoryImpl(remote: remote);

    final result = await repository.getHome();

    final failure = result.fold<HomeFailure?>(
      onSuccess: (_) => null,
      onFailure: (value) => value,
    );
    expect(failure?.type, HomeFailureType.network);
  });
}
