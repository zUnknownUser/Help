import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../notifications/data/push_providers.dart';

class NotificationPreferencesPage extends ConsumerStatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  ConsumerState<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends ConsumerState<NotificationPreferencesPage> {
  NotificationSettings? _settings;
  bool _loading = true;
  bool _requesting = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        _settings?.authorizationStatus == AuthorizationStatus.authorized ||
        _settings?.authorizationStatus == AuthorizationStatus.provisional;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notificações')),
      body: _loading
          ? const AppLoadingView(message: 'Verificando notificações…')
          : _loadFailed
          ? _NotificationSettingsError(onRetry: _retry)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        enabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_outlined,
                        color: enabled
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enabled
                                  ? 'Notificações ativadas'
                                  : 'Notificações desativadas',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'O Help avisa sobre pedidos, mudanças de status e novas mensagens.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!enabled)
                  AppButton(
                    label: 'Permitir notificações',
                    isLoading: _requesting,
                    onPressed: _requesting ? null : _request,
                  ),
                const SizedBox(height: 18),
                const Text(
                  'Os avisos também ficam salvos dentro do aplicativo. Assim, mesmo que um push falhe ou esteja desativado, nenhuma atualização importante do pedido é perdida.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
    );
  }

  Future<void> _load() async {
    try {
      final settings = await ref
          .read(pushMessagingGatewayProvider)
          .notificationSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    await _load();
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      await ref.read(pushMessagingGatewayProvider).requestPermission();
      await ref.read(pushRegistrationServiceProvider).start();
      await _load();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }
}

class _NotificationSettingsError extends StatelessWidget {
  const _NotificationSettingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            color: AppColors.primary,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Não foi possível verificar suas notificações.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            child: AppButton(label: 'Tentar novamente', onPressed: onRetry),
          ),
        ],
      ),
    ),
  );
}
