import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../home/domain/entities/home_location.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_role.dart';
import 'account_profile_header.dart';
import 'account_section.dart';

class AccountContent extends StatelessWidget {
  const AccountContent({
    required this.profile,
    required this.location,
    required this.roleLoading,
    required this.signOutLoading,
    required this.onProfile,
    required this.onRequests,
    required this.onChat,
    required this.onLocation,
    required this.onNotifications,
    required this.onProfessionalArea,
    required this.onSecurity,
    required this.onHelp,
    required this.onAbout,
    required this.onSwitchRole,
    required this.onSignOut,
    this.roleError,
    super.key,
  });

  final UserProfile profile;
  final HomeLocation location;
  final bool roleLoading;
  final bool signOutLoading;
  final String? roleError;
  final VoidCallback onProfile;
  final VoidCallback onRequests;
  final VoidCallback onChat;
  final VoidCallback onLocation;
  final VoidCallback onNotifications;
  final VoidCallback onProfessionalArea;
  final VoidCallback onSecurity;
  final VoidCallback onHelp;
  final VoidCallback onAbout;
  final VoidCallback? onSwitchRole;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Conta')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              AccountProfileHeader(profile: profile, onTap: onProfile),
              const SizedBox(height: 22),
              _activity(),
              const SizedBox(height: 18),
              _preferences(),
              if (profile.activeRole == UserRole.provider) ...[
                const SizedBox(height: 18),
                _professional(),
              ],
              const SizedBox(height: 18),
              _support(),
              const SizedBox(height: 18),
              _session(),
              if (roleError case final message?) ...[
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  AccountSection _activity() => AccountSection(
    title: 'Atividade',
    children: [
      AccountTile(
        icon: Icons.assignment_outlined,
        title: profile.activeRole == UserRole.customer
            ? 'Meus pedidos'
            : 'Solicitações recebidas',
        subtitle: 'Acompanhe agendamentos e mudanças de status',
        onTap: onRequests,
      ),
      AccountTile(
        icon: Icons.forum_outlined,
        iconAsset: 'assets/icons/conversations.png',
        assetColor: AppColors.primary,
        title: 'Conversas',
        subtitle: 'Mensagens com clientes e profissionais',
        onTap: onChat,
      ),
    ],
  );

  AccountSection _preferences() => AccountSection(
    title: 'Preferências',
    children: [
      AccountTile(
        icon: Icons.location_on_outlined,
        title: profile.activeRole == UserRole.customer
            ? 'Endereço e localização'
            : 'Área de atendimento',
        subtitle: location.address.isEmpty
            ? 'Defina sua localização atual'
            : location.address,
        onTap: onLocation,
      ),
      AccountTile(
        icon: Icons.notifications_none_rounded,
        title: 'Notificações',
        subtitle: 'Pedidos, atualizações e mensagens',
        onTap: onNotifications,
      ),
    ],
  );

  AccountSection _professional() => AccountSection(
    title: 'Perfil profissional',
    children: [
      AccountTile(
        icon: Icons.verified_outlined,
        title: 'Situação do perfil',
        subtitle: _providerStatus(profile),
        onTap: null,
        trailing: _ProviderStatusDot(profile: profile),
      ),
      AccountTile(
        icon: Icons.home_repair_service_outlined,
        title: 'Serviços e disponibilidade',
        subtitle: 'Voltar para sua área profissional',
        onTap: onProfessionalArea,
      ),
    ],
  );

  AccountSection _support() => AccountSection(
    title: 'Privacidade e suporte',
    children: [
      AccountTile(
        icon: Icons.shield_outlined,
        title: 'Segurança e privacidade',
        subtitle: 'Sessão protegida e controle dos seus dados',
        onTap: onSecurity,
      ),
      AccountTile(
        icon: Icons.help_outline_rounded,
        title: 'Ajuda',
        subtitle: 'Dúvidas sobre pedidos, conta e atendimento',
        onTap: onHelp,
      ),
      AccountTile(
        icon: Icons.info_outline_rounded,
        title: 'Sobre o Help',
        subtitle: 'Versão 1.0.0',
        onTap: onAbout,
      ),
    ],
  );

  AccountSection _session() => AccountSection(
    title: 'Perfil e sessão',
    children: [
      AccountTile(
        icon: Icons.swap_horiz_rounded,
        title: _roleSwitchLabel(profile),
        subtitle: 'Alterne sua experiência sem criar outra conta',
        onTap: onSwitchRole,
        trailing: roleLoading
            ? const AppProgressIndicator(
                size: 18,
                semanticsLabel: 'Alterando perfil',
              )
            : null,
      ),
      AccountTile(
        key: const Key('customer_sign_out_button'),
        icon: Icons.logout_rounded,
        iconAsset: profile.activeRole == UserRole.provider
            ? 'assets/illustrations/provider_sign_out.png'
            : 'assets/icons/sign_out.png',
        assetPadding: 3,
        iconColor: AppColors.danger,
        title: 'Sair da conta',
        onTap: onSignOut,
        trailing: signOutLoading
            ? const AppProgressIndicator(
                size: 18,
                semanticsLabel: 'Saindo da conta',
              )
            : null,
      ),
    ],
  );
}

String _roleSwitchLabel(UserProfile profile) {
  if (profile.activeRole == UserRole.customer) {
    return profile.roles.contains(UserRole.provider)
        ? 'Usar perfil profissional'
        : 'Também quero oferecer serviços';
  }
  return profile.roles.contains(UserRole.customer)
      ? 'Usar perfil de cliente'
      : 'Também quero contratar serviços';
}

String _providerStatus(UserProfile profile) => switch (profile.providerStatus) {
  ProviderOnboardingStatus.approved =>
    'Perfil aprovado e disponível para operar',
  ProviderOnboardingStatus.rejected => 'Perfil precisa de revisão',
  _ => 'Perfil em análise',
};

class _ProviderStatusDot extends StatelessWidget {
  const _ProviderStatusDot({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final color = switch (profile.providerStatus) {
      ProviderOnboardingStatus.approved => AppColors.primary,
      ProviderOnboardingStatus.rejected => AppColors.danger,
      _ => AppColors.amber,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
