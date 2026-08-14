import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/provider_workspace_repository.dart';
import '../data_sources/http_provider_workspace_remote_data_source.dart';
import '../data_sources/provider_workspace_remote_data_source.dart';
import '../repositories/provider_workspace_repository_impl.dart';

final providerWorkspaceRemoteDataSourceProvider =
    Provider<ProviderWorkspaceRemoteDataSource>(
      (ref) => HttpProviderWorkspaceRemoteDataSource(
        client: ref.watch(authenticatedHttpClientProvider),
        baseUrl: AppConfig.apiBaseUrl,
      ),
    );

final providerWorkspaceRepositoryProvider =
    Provider<ProviderWorkspaceRepository>(
      (ref) => ProviderWorkspaceRepositoryImpl(
        ref.watch(providerWorkspaceRemoteDataSourceProvider),
      ),
    );
