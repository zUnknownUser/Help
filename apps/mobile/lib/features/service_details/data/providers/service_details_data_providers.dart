import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/service_details_repository.dart';
import '../data_sources/http_service_details_remote_data_source.dart';
import '../data_sources/service_details_remote_data_source.dart';
import '../repositories/service_details_repository_impl.dart';

final serviceDetailsRemoteDataSourceProvider =
    Provider<ServiceDetailsRemoteDataSource>(
      (ref) => HttpServiceDetailsRemoteDataSource(
        client: ref.watch(authenticatedHttpClientProvider),
        baseUrl: AppConfig.apiBaseUrl,
      ),
    );

final serviceDetailsRepositoryProvider = Provider<ServiceDetailsRepository>(
  (ref) => ServiceDetailsRepositoryImpl(
    ref.watch(serviceDetailsRemoteDataSourceProvider),
  ),
);
