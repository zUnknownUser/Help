import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_brand.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';
import '../../domain/entities/user_role.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

class ProviderHomePage extends ConsumerWidget {
  const ProviderHomePage({required this.profile, super.key});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _contentFor(profile.providerStatus);
    final roleState = ref.watch(profileRoleControllerProvider);
    final unreadChat = ref.watch(unreadChatCountProvider).value ?? 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const AppBrand(),
        actions: [
          IconButton(
            tooltip: 'Conversas',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const ChatListPage()),
            ),
            icon: Badge(
              isLabelVisible: unreadChat > 0,
              label: Text(unreadChat > 99 ? '99+' : '$unreadChat'),
              child: const Icon(Icons.forum_outlined),
            ),
          ),
          IconButton(
            key: const Key('provider_sign_out_button'),
            tooltip: 'Sair',
            onPressed: () => ref.read(signOutProvider)(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.outline),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: content.color.withValues(alpha: .12),
                      foregroundColor: content.color,
                      child: Icon(content.icon, size: 32),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Olá, ${profile.displayName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      content.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Atualizar status',
                      variant: AppButtonVariant.outlined,
                      onPressed: ref
                          .read(currentProfileProvider.notifier)
                          .retry,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      key: const Key('activate_customer_role_button'),
                      label: profile.roles.contains(UserRole.customer)
                          ? 'Usar perfil de cliente'
                          : 'Também quero contratar serviços',
                      variant: AppButtonVariant.outlined,
                      isLoading: roleState.isLoading,
                      onPressed: roleState.isLoading
                          ? null
                          : () => ref
                                .read(profileRoleControllerProvider.notifier)
                                .activate(
                                  role: UserRole.customer,
                                  displayName: profile.displayName,
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

_ProviderStatusContent _contentFor(
  ProviderOnboardingStatus? status,
) => switch (status) {
  ProviderOnboardingStatus.approved => const _ProviderStatusContent(
    title: 'Seu perfil profissional está ativo',
    description:
        'Novas oportunidades aparecerão aqui quando clientes solicitarem serviços compatíveis.',
    icon: Icons.verified_rounded,
    color: AppColors.primary,
  ),
  ProviderOnboardingStatus.rejected => const _ProviderStatusContent(
    title: 'Precisamos revisar seus dados',
    description:
        'Seu perfil ainda não pode receber pedidos. Em breve você poderá corrigir os dados diretamente por aqui.',
    icon: Icons.info_outline_rounded,
    color: AppColors.danger,
  ),
  _ => const _ProviderStatusContent(
    title: 'Seu perfil está em análise',
    description:
        'Estamos preparando sua área profissional. Você será avisado assim que o perfil estiver liberado para receber pedidos.',
    icon: Icons.hourglass_top_rounded,
    color: AppColors.amber,
  ),
};

class _ProviderStatusContent {
  const _ProviderStatusContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}
