import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/providers/auth_data_providers.dart';
import '../domain/repositories/scheduling_repository.dart';
import 'scheduling_remote_api.dart';
import 'scheduling_repository_impl.dart';

final schedulingApiProvider = Provider(
  (ref) => SchedulingRemoteApi(
    client: ref.watch(authenticatedHttpClientProvider),
    baseUrl: AppConfig.apiBaseUrl,
  ),
);
final schedulingRepositoryProvider = Provider<SchedulingRepository>(
  (ref) => SchedulingRepositoryImpl(ref.watch(schedulingApiProvider)),
);
