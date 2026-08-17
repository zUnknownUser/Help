import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/providers/auth_data_providers.dart';
import '../domain/repositories/help_now_repository.dart';
import 'help_now_remote_api.dart';
import 'help_now_repository_impl.dart';

final helpNowRemoteApiProvider = Provider<HelpNowRemoteApi>(
  (ref) => HelpNowRemoteApi(
    client: ref.watch(authenticatedHttpClientProvider),
    baseUrl: AppConfig.apiBaseUrl,
  ),
);

final helpNowRepositoryProvider = Provider<HelpNowRepository>(
  (ref) => HelpNowRepositoryImpl(ref.watch(helpNowRemoteApiProvider)),
);
