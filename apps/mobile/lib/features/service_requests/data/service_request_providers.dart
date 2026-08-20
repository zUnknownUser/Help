import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/providers/auth_data_providers.dart';
import '../domain/repositories/service_request_repository.dart';
import 'service_request_remote_api.dart';
import 'service_request_repository_impl.dart';

final serviceRequestRemoteApiProvider = Provider<ServiceRequestRemoteApi>(
  (ref) => ServiceRequestRemoteApi(
    client: ref.watch(authenticatedHttpClientProvider),
    baseUrl: AppConfig.apiBaseUrl,
  ),
);

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>(
  (ref) => ServiceRequestRepositoryImpl(
    ref.watch(serviceRequestRemoteApiProvider),
  ),
);
