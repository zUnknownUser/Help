import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client_provider.dart';
import '../../domain/repositories/home_repository.dart';
import '../data_sources/home_cache_data_source.dart';
import '../data_sources/home_remote_data_source.dart';
import '../data_sources/http_home_remote_data_source.dart';
import '../repositories/home_repository_impl.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>(
  (ref) => HttpHomeRemoteDataSource(
    client: ref.watch(httpClientProvider),
    baseUrl: AppConfig.apiBaseUrl,
  ),
);

final homeCacheDataSourceProvider = Provider<HomeCacheDataSource>(
  (_) => InMemoryHomeCacheDataSource(),
);

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepositoryImpl(
    remote: ref.watch(homeRemoteDataSourceProvider),
    cache: ref.watch(homeCacheDataSourceProvider),
  ),
);
