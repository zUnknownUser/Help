import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/provider_data_providers.dart';
import '../../domain/entities/provider_workspace.dart';
import '../../domain/use_cases/get_provider_home.dart';
import '../../domain/use_cases/provider_workspace_actions.dart';
import '../controllers/provider_workspace_controller.dart';

final getProviderHomeProvider = Provider<GetProviderHome>(
  (ref) => GetProviderHome(ref.watch(providerWorkspaceRepositoryProvider)),
);

final providerWorkspaceActionsProvider = Provider<ProviderWorkspaceActions>(
  (ref) =>
      ProviderWorkspaceActions(ref.watch(providerWorkspaceRepositoryProvider)),
);

final providerWorkspaceControllerProvider =
    AsyncNotifierProvider.autoDispose<
      ProviderWorkspaceController,
      ProviderWorkspace
    >(ProviderWorkspaceController.new, retry: (_, _) => null);
