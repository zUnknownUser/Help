import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/reviews/app_store_review_service.dart';
import '../../auth/data/providers/auth_data_providers.dart';
import '../data/service_review_api.dart';
import '../domain/service_review.dart';

final serviceReviewApiProvider = Provider<ServiceReviewApi>(
  (ref) => ServiceReviewApi(
    ref.watch(authenticatedHttpClientProvider),
    AppConfig.apiBaseUrl,
  ),
);

final serviceReviewsProvider = FutureProvider.autoDispose
    .family<List<ServiceReview>, String>(
      (ref, requestId) => ref.watch(serviceReviewApiProvider).list(requestId),
    );

final appStoreReviewServiceProvider = Provider<AppStoreReviewService>(
  (_) => AppStoreReviewService(),
);
