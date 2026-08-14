import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/http_client_provider.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/home_interaction_repository.dart';
import '../../domain/repositories/home_repository.dart';
import '../data_sources/home_remote_data_source.dart';
import '../data_sources/http_home_remote_data_source.dart';
import '../repositories/home_repository_impl.dart';
import '../data_sources/home_interaction_remote_data_source.dart';
import '../data_sources/http_home_interaction_remote_data_source.dart';
import '../repositories/home_interaction_repository_impl.dart';
import '../../domain/services/location_resolver.dart';
import '../services/device_location_resolver.dart';
import '../data_sources/catalog_remote_data_source.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>(
  (ref) => HttpHomeRemoteDataSource(
    client: ref.watch(authenticatedHttpClientProvider),
    baseUrl: AppConfig.apiBaseUrl,
  ),
);

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepositoryImpl(remote: ref.watch(homeRemoteDataSourceProvider)),
);

final homeInteractionRemoteDataSourceProvider =
    Provider<HomeInteractionRemoteDataSource>(
      (ref) => HttpHomeInteractionRemoteDataSource(
        client: ref.watch(authenticatedHttpClientProvider),
        baseUrl: AppConfig.apiBaseUrl,
      ),
    );

final homeInteractionRepositoryProvider = Provider<HomeInteractionRepository>(
  (ref) => HomeInteractionRepositoryImpl(
    ref.watch(homeInteractionRemoteDataSourceProvider),
  ),
);

final locationResolverProvider = Provider<LocationResolver>(
  (ref) => DeviceLocationResolver(ref.watch(httpClientProvider)),
);

final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>(
  (ref) => CatalogRemoteDataSource(
    client: ref.watch(authenticatedHttpClientProvider),
    baseUrl: AppConfig.apiBaseUrl,
  ),
);
