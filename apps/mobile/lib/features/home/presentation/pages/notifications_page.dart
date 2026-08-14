import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/home_notification.dart';
import '../providers/home_providers.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({required this.notifications, super.key});

  final List<HomeNotification> notifications;

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final Set<String> _readDuringSession = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notificações')),
      body: widget.notifications.isEmpty
          ? const _EmptyNotifications()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = widget.notifications[index];
                final read =
                    notification.read ||
                    _readDuringSession.contains(notification.id);
                return ListTile(
                  tileColor: read ? AppColors.surface : AppColors.primarySoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    read
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_active_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    notification.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(notification.body),
                  onTap: read ? null : () => _markRead(notification.id),
                );
              },
            ),
    );
  }

  Future<void> _markRead(String id) async {
    final success = await ref
        .read(homeActionControllerProvider.notifier)
        .markNotificationRead(id);
    if (!mounted) return;
    if (success) {
      setState(() => _readDuringSession.add(id));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível atualizar a notificação.'),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 44,
              color: AppColors.primary,
            ),
            SizedBox(height: 12),
            Text(
              'Nenhuma notificação por enquanto.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
