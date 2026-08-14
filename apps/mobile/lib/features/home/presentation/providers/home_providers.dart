import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/home_data_providers.dart';
import '../../domain/entities/home_content.dart';
import '../../domain/use_cases/get_home.dart';
import '../../domain/use_cases/save_home_location.dart';
import '../../domain/use_cases/mark_notification_read.dart';
import '../controllers/home_controller.dart';
import '../controllers/home_action_controller.dart';
import '../controllers/home_action_state.dart';

final getHomeProvider = Provider<GetHome>(
  (ref) => GetHome(ref.watch(homeRepositoryProvider)),
);

final homeControllerProvider =
    AsyncNotifierProvider.autoDispose<HomeController, HomeContent>(
      HomeController.new,
      retry: (_, _) => null,
    );

final saveHomeLocationProvider = Provider<SaveHomeLocation>(
  (ref) => SaveHomeLocation(ref.watch(homeInteractionRepositoryProvider)),
);

final markNotificationReadProvider = Provider<MarkNotificationRead>(
  (ref) => MarkNotificationRead(ref.watch(homeInteractionRepositoryProvider)),
);

final homeActionControllerProvider =
    NotifierProvider.autoDispose<HomeActionController, HomeActionState>(
      HomeActionController.new,
    );
