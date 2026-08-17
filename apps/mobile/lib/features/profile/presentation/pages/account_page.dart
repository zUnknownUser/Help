import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../home/domain/entities/home_location.dart';
import '../../../home/presentation/pages/location_page.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../main_navigation/presentation/main_tab.dart';
import '../../../provider/presentation/providers/provider_workspace_providers.dart';
import '../../../service_requests/presentation/pages/service_requests_page.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_role.dart';
import '../extensions/profile_failure_message.dart';
import '../providers/profile_providers.dart';
import '../widgets/account_content.dart';
import 'account_info_page.dart';
import 'account_profile_page.dart';
import 'notification_preferences_page.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({this.onTabSelected, super.key});

  final ValueChanged<MainTab>? onTabSelected;

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  bool _signingOut = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: AppLoadingView(message: 'Carregando sua conta…'),
      );
    }
    final roleState = ref.watch(profileRoleControllerProvider);
    return AccountContent(
      profile: profile,
      location: _location(ref, profile),
      roleLoading: roleState.isLoading,
      signOutLoading: _signingOut,
      roleError: roleState.failure?.userMessage,
      onProfile: () => _open(context, AccountProfilePage(profile: profile)),
      onRequests: () =>
          _openTab(context, MainTab.requests, const ServiceRequestsPage()),
      onChat: () =>
          _openTab(context, MainTab.conversations, const ChatListPage()),
      onLocation: () => _openLocation(context, ref, profile),
      onNotifications: () =>
          _open(context, const NotificationPreferencesPage()),
      onProfessionalArea: () =>
          _openTab(context, MainTab.home, const SizedBox.shrink()),
      onSecurity: () => _openInfo(
        context,
        'Segurança e privacidade',
        Icons.shield_outlined,
        'Sua autenticação é protegida pelo Firebase. O aplicativo nunca armazena sua senha e as ações de pedidos são autorizadas novamente no servidor usando sua identidade.',
      ),
      onHelp: () => _openInfo(
        context,
        'Central de ajuda',
        Icons.help_outline_rounded,
        'Consulte o andamento pelo menu Pedidos. Em caso de problema com um atendimento, preserve a conversa e os detalhes da solicitação para facilitar o suporte.',
      ),
      onAbout: () => _openInfo(
        context,
        'Sobre o Help',
        Icons.handshake_outlined,
        'O Help aproxima pessoas que precisam de serviços de profissionais disponíveis, com comunicação e acompanhamento em um único lugar.',
      ),
      onSwitchRole: roleState.isLoading
          ? null
          : () => _switchRole(context, ref, profile),
      onSignOut: _signingOut ? null : () => _signOut(context, ref),
    );
  }

  HomeLocation _location(WidgetRef ref, UserProfile profile) {
    if (profile.activeRole == UserRole.provider) {
      final location = ref
          .watch(providerWorkspaceControllerProvider)
          .value
          ?.location;
      return HomeLocation(
        address: location?.address ?? '',
        availabilityLabel: 'Área de atendimento',
        latitude: location?.latitude,
        longitude: location?.longitude,
      );
    }
    return ref.watch(homeControllerProvider).value?.location ??
        const HomeLocation(address: '', availabilityLabel: '');
  }

  Future<void> _openLocation(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LocationPage(current: _location(ref, profile)),
      ),
    );
    if (changed != true) return;
    if (profile.activeRole == UserRole.provider) {
      await ref.read(providerWorkspaceControllerProvider.notifier).retry();
    } else {
      await ref.read(homeControllerProvider.notifier).retry();
    }
  }

  Future<void> _switchRole(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final target = profile.activeRole == UserRole.customer
        ? UserRole.provider
        : UserRole.customer;
    final success = await ref
        .read(profileRoleControllerProvider.notifier)
        .activate(role: target, displayName: profile.displayName);
    if (success && context.mounted) {
      final select = widget.onTabSelected;
      if (select != null) {
        select(MainTab.home);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'As mensagens pendentes continuarão salvas neste dispositivo para a próxima sessão desta conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(signOutProvider)();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));

  void _openTab(BuildContext context, MainTab tab, Widget fallback) {
    final select = widget.onTabSelected;
    if (select != null) {
      select(tab);
      return;
    }
    if (tab == MainTab.home) {
      Navigator.of(context).maybePop();
      return;
    }
    _open(context, fallback);
  }

  void _openInfo(
    BuildContext context,
    String title,
    IconData icon,
    String description,
  ) => _open(
    context,
    AccountInfoPage(title: title, icon: icon, description: description),
  );
}
