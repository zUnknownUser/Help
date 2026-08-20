import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/data/providers/chat_data_providers.dart';
import '../../../chat/data/realtime/chat_realtime_coordinator.dart';
import '../../data/service_request_providers.dart';
import '../../domain/use_cases/service_request_actions.dart';
import '../controllers/service_requests_controller.dart';
import '../controllers/service_requests_state.dart';

final serviceRequestActionsProvider = Provider<ServiceRequestActions>(
  (ref) => ServiceRequestActions(ref.watch(serviceRequestRepositoryProvider)),
);

final serviceRequestAttachmentBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, attachmentId) {
      return ref
          .watch(serviceRequestRemoteApiProvider)
          .attachmentBytes(attachmentId);
    });

final serviceRequestRealtimeEventProvider = StreamProvider<RealtimeAppEvent>(
  (ref) => ref
      .watch(chatRealtimeCoordinatorProvider)
      .appEvents
      .where((event) => event.type.startsWith('service_request.')),
);

final serviceRequestsControllerProvider =
    NotifierProvider.autoDispose<
      ServiceRequestsController,
      ServiceRequestsState
    >(ServiceRequestsController.new);
