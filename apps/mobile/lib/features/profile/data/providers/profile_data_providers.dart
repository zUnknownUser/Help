import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/profile_repository.dart';
import '../data_sources/http_profile_remote_data_source.dart';
import '../data_sources/profile_remote_data_source.dart';
import '../repositories/profile_repository_impl.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (ref) => HttpProfileRemoteDataSource(
    client: ref.watch(authenticatedHttpClientProvider),
    baseUrl: AppConfig.apiBaseUrl,
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider)),
);
