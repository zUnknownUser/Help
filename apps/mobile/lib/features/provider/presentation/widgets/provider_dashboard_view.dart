import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_brand.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
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
    required this.onRefresh,
    required this.onAvailabilityChanged,
    required this.onAlert,
    required this.onCreateService,
    required this.onEditService,
    required this.onPublishedChanged,
    required this.onDeleteService,
    required this.onAccount,
    required this.onNotifications,
    required this.onSchedule,
    required this.onAgenda,
    this.onRequests,
    this.onRequest,
    this.helpNowCard,
    super.key,
  });

  final ProviderWorkspace workspace;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onAvailabilityChanged;
  final ValueChanged<ProviderAlert> onAlert;
  final VoidCallback onCreateService;
  final ValueChanged<ProviderService> onEditService;
  final void Function(ProviderService, bool) onPublishedChanged;
  final ValueChanged<ProviderService> onDeleteService;
  final VoidCallback onAccount;
  final VoidCallback onNotifications;
  final VoidCallback onSchedule;
  final VoidCallback onAgenda;
  final VoidCallback? onRequests;
  final ValueChanged<ProviderRequest>? onRequest;
  final Widget? helpNowCard;

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
                if (helpNowCard case final card?) ...[
                  const SizedBox(height: 12),
                  card,
                ],
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
                const SizedBox(height: 18),
                _ScheduleCard(
                  icon: Icons.today_outlined,
                  title: 'Minha agenda',
                  subtitle: 'Veja os atendimentos da semana',
                  onTap: onAgenda,
                ),
                const SizedBox(height: 10),
                _ScheduleCard(
                  icon: Icons.schedule_outlined,
                  title: 'Horários e disponibilidade',
                  subtitle: 'Defina jornada, intervalos e bloqueios',
                  onTap: onSchedule,
                ),
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
                ProviderRequestsSection(
                  requests: workspace.recentRequests,
                  onRequest: onRequest ?? (_) {},
                  onViewAll: onRequests ?? () {},
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}
