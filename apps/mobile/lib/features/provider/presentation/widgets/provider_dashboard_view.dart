import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_brand.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../home/presentation/widgets/home_nav_bar.dart';
import '../../domain/entities/provider_service.dart';
import '../../domain/entities/provider_workspace.dart';
import 'provider_alert_card.dart';
import 'provider_requests_section.dart';
import 'provider_services_section.dart';
import 'provider_summary_grid.dart';
import 'provider_welcome_card.dart';

class ProviderDashboardView extends StatelessWidget {
  const ProviderDashboardView({
    required this.workspace,
    required this.chatUnreadCount,
    required this.onRefresh,
    required this.onAvailabilityChanged,
    required this.onAlert,
    required this.onCreateService,
    required this.onEditService,
    required this.onPublishedChanged,
    required this.onDeleteService,
    required this.onConversations,
    required this.onAccount,
    required this.onNotifications,
    super.key,
  });

  final ProviderWorkspace workspace;
  final int chatUnreadCount;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onAvailabilityChanged;
  final ValueChanged<ProviderAlert> onAlert;
  final VoidCallback onCreateService;
  final ValueChanged<ProviderService> onEditService;
  final void Function(ProviderService, bool) onPublishedChanged;
  final ValueChanged<ProviderService> onDeleteService;
  final VoidCallback onConversations;
  final VoidCallback onAccount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      title: const AppBrand(compact: true),
      actions: [
        IconButton(
          tooltip: 'Notificações',
          onPressed: onNotifications,
          icon: Badge(
            isLabelVisible: workspace.summary.unreadNotifications > 0,
            label: Text(
              workspace.summary.unreadNotifications > 99
                  ? '99+'
                  : '${workspace.summary.unreadNotifications}',
            ),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        IconButton(
          tooltip: 'Conta',
          onPressed: onAccount,
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
    ),
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                ProviderWelcomeCard(
                  workspace: workspace,
                  onAvailabilityChanged: onAvailabilityChanged,
                ),
                if (workspace.alerts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...workspace.alerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: ProviderAlertCard(
                        alert: alert,
                        onTap: () => onAlert(alert),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ProviderSummaryGrid(summary: workspace.summary),
                const SizedBox(height: 22),
                AppButton(
                  key: const Key('provider_create_service_button'),
                  label: 'Cadastrar serviço',
                  leading: const Icon(Icons.add_rounded, size: 19),
                  onPressed: onCreateService,
                ),
                const SizedBox(height: 26),
                ProviderServicesSection(
                  services: workspace.services,
                  onCreate: onCreateService,
                  onEdit: onEditService,
                  onPublishedChanged: onPublishedChanged,
                  onDelete: onDeleteService,
                ),
                const SizedBox(height: 28),
                ProviderRequestsSection(requests: workspace.recentRequests),
              ],
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: HomeNavBar(
      chatUnreadCount: chatUnreadCount,
      onConversationsTap: onConversations,
      onAccountTap: onAccount,
    ),
  );
}
