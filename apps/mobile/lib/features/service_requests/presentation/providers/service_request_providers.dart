import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/service_request_providers.dart';
import '../../domain/use_cases/service_request_actions.dart';
import '../controllers/service_requests_controller.dart';
import '../controllers/service_requests_state.dart';

final serviceRequestActionsProvider = Provider<ServiceRequestActions>(
  (ref) => ServiceRequestActions(ref.watch(serviceRequestRepositoryProvider)),
);

final serviceRequestsControllerProvider =
    NotifierProvider.autoDispose<
      ServiceRequestsController,
      ServiceRequestsState
    >(ServiceRequestsController.new);
