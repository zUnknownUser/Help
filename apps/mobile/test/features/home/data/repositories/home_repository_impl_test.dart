import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/data/data_sources/home_cache_data_source.dart';
import 'package:help/features/home/data/data_sources/home_remote_data_source.dart';
import 'package:help/features/home/data/errors/home_data_exception.dart';
import 'package:help/features/home/data/models/home_content_model.dart';
import 'package:help/features/home/data/repositories/home_repository_impl.dart';
import 'package:help/features/home/domain/failures/home_failure.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeRemoteDataSource extends Mock implements HomeRemoteDataSource {}

class _MockHomeCacheDataSource extends Mock implements HomeCacheDataSource {}

void main() {
  const model = HomeContentModel.empty();

  test('salva no cache a resposta recebida da API', () async {
    final remote = _MockHomeRemoteDataSource();
    final cache = _MockHomeCacheDataSource();
    when(remote.fetchHome).thenAnswer((_) async => model);
    when(() => cache.write(model)).thenReturn(null);
    final repository = HomeRepositoryImpl(remote: remote, cache: cache);

    final result = await repository.getHome();

    expect(result.isSuccess, isTrue);
    verify(() => cache.write(model)).called(1);
  });

  test('usa o último conteúdo em cache quando a rede falha', () async {
    final remote = _MockHomeRemoteDataSource();
    final cache = _MockHomeCacheDataSource();
    when(
      remote.fetchHome,
    ).thenThrow(const HomeDataException(HomeDataErrorCode.network));
    when(cache.read).thenReturn(model);
    final repository = HomeRepositoryImpl(remote: remote, cache: cache);

    final result = await repository.getHome();

    expect(result.isSuccess, isTrue);
  });

  test(
    'expõe falha de domínio quando API e cache não estão disponíveis',
    () async {
      final remote = _MockHomeRemoteDataSource();
      final cache = _MockHomeCacheDataSource();
      when(
        remote.fetchHome,
      ).thenThrow(const HomeDataException(HomeDataErrorCode.network));
      when(cache.read).thenReturn(null);
      final repository = HomeRepositoryImpl(remote: remote, cache: cache);

      final result = await repository.getHome();

      final failure = result.fold<HomeFailure?>(
        onSuccess: (_) => null,
        onFailure: (value) => value,
      );
      expect(failure?.type, HomeFailureType.network);
    },
  );
}
