import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/home_data_providers.dart';
import '../../domain/entities/home_content.dart';
import '../../domain/use_cases/get_home.dart';
import '../controllers/home_controller.dart';

final getHomeProvider = Provider<GetHome>(
  (ref) => GetHome(ref.watch(homeRepositoryProvider)),
);

final homeControllerProvider =
    AsyncNotifierProvider.autoDispose<HomeController, HomeContent>(
      HomeController.new,
      retry: (_, _) => null,
    );
