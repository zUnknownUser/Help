import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/user_role.dart';
import '../providers/profile_providers.dart';
import '../extensions/profile_failure_message.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final roleState = ref.watch(profileRoleControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Minha conta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primary,
                    child: Icon(Icons.person_outline_rounded, size: 34),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profile?.displayName ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.email ?? '',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  if (profile != null)
                    Chip(
                      label: Text(
                        profile.activeRole == UserRole.customer
                            ? 'Buscando serviços'
                            : 'Oferecendo serviços',
                      ),
                      backgroundColor: AppColors.primarySoft,
                      side: BorderSide.none,
                    ),
                  const SizedBox(height: 28),
                  if (profile != null) ...[
                    AppButton(
                      key: const Key('activate_provider_role_button'),
                      label: profile.roles.contains(UserRole.provider)
                          ? 'Usar perfil profissional'
                          : 'Também quero oferecer serviços',
                      isLoading: roleState.isLoading,
                      onPressed: roleState.isLoading
                          ? null
                          : () => _activateProvider(
                              context,
                              ref,
                              profile.displayName,
                            ),
                    ),
                    if (roleState.failure case final failure?) ...[
                      const SizedBox(height: 8),
                      Text(
                        failure.userMessage,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                  AppButton(
                    key: const Key('customer_sign_out_button'),
                    label: 'Sair da conta',
                    variant: AppButtonVariant.outlined,
                    leading: const Icon(Icons.logout_rounded, size: 18),
                    onPressed: () => ref.read(signOutProvider)(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _activateProvider(
    BuildContext context,
    WidgetRef ref,
    String displayName,
  ) async {
    final success = await ref
        .read(profileRoleControllerProvider.notifier)
        .activate(role: UserRole.provider, displayName: displayName);
    if (success && context.mounted) Navigator.of(context).pop();
  }
}
