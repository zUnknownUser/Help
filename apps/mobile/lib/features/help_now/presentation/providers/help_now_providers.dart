import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/help_now_availability.dart';
import '../../domain/entities/help_now_request.dart';
import '../controllers/customer_help_now_controller.dart';
import '../controllers/provider_help_now_controller.dart';
import '../../../chat/data/providers/chat_data_providers.dart';
import '../../../chat/data/realtime/chat_realtime_coordinator.dart';

final customerHelpNowControllerProvider =
    AsyncNotifierProvider<CustomerHelpNowController, HelpNowRequest?>(
      CustomerHelpNowController.new,
    );

final providerHelpNowControllerProvider =
    AsyncNotifierProvider<ProviderHelpNowController, ProviderHelpNowState>(
      ProviderHelpNowController.new,
    );

final helpNowRealtimeEventProvider = StreamProvider<RealtimeAppEvent>(
  (ref) => ref
      .watch(chatRealtimeCoordinatorProvider)
      .appEvents
      .where((event) => event.type.startsWith('help_now.')),
);
