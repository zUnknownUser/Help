import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/profile_data_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/use_cases/get_current_profile.dart';
import '../../domain/use_cases/register_profile.dart';
import '../controllers/profile_controller.dart';
import '../controllers/profile_setup_controller.dart';
import '../controllers/profile_setup_state.dart';
import '../controllers/profile_role_controller.dart';
import '../controllers/profile_role_state.dart';

final getCurrentProfileProvider = Provider<GetCurrentProfile>(
  (ref) => GetCurrentProfile(ref.watch(profileRepositoryProvider)),
);

final registerProfileProvider = Provider<RegisterProfile>(
  (ref) => RegisterProfile(ref.watch(profileRepositoryProvider)),
);

final currentProfileProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, UserProfile>(
      ProfileController.new,
      retry: (_, _) => null,
    );

final profileSetupControllerProvider =
    NotifierProvider.autoDispose<ProfileSetupController, ProfileSetupState>(
      ProfileSetupController.new,
    );

final profileRoleControllerProvider =
    NotifierProvider.autoDispose<ProfileRoleController, ProfileRoleState>(
      ProfileRoleController.new,
    );
