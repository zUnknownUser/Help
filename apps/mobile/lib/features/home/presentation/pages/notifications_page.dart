import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../domain/entities/home_notification.dart';
import '../providers/home_providers.dart';
import '../../../chat/data/providers/chat_data_providers.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../service_requests/presentation/pages/service_request_details_page.dart';

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
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed:
                  ref.watch(notificationActionControllerProvider).markingAll
                  ? null
                  : _markAll,
              child: const Text('Ler todas'),
            ),
        ],
      ),
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
                  onTap: () => _handle(notification, read: read),
                );
              },
            ),
    );
  }

  bool get _hasUnread => widget.notifications.any(
    (item) => !item.read && !_readDuringSession.contains(item.id),
  );

  Future<void> _markRead(String id) async {
    setState(() => _readDuringSession.add(id));
    final success = await ref
        .read(notificationActionControllerProvider.notifier)
        .markOne(id);
    if (!mounted) return;
    if (success) return;
    setState(() => _readDuringSession.remove(id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível atualizar a notificação.'),
      ),
    );
  }

  Future<void> _markAll() async {
    final unread = widget.notifications
        .where((item) => !item.read)
        .map((item) => item.id)
        .toSet();
    setState(() => _readDuringSession.addAll(unread));
    final success = await ref
        .read(notificationActionControllerProvider.notifier)
        .markAll();
    if (!mounted || success) return;
    setState(() => _readDuringSession.removeAll(unread));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível marcar todas como lidas.'),
      ),
    );
  }

  Future<void> _handle(
    HomeNotification notification, {
    required bool read,
  }) async {
    if (!read) await _markRead(notification.id);
    if (!mounted) return;
    if (notification.kind == 'service_request' ||
        notification.kind == 'service_review') {
      final requestId = notification.data['request_id'];
      if (requestId != null && requestId.isNotEmpty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ServiceRequestDetailsPage(requestId: requestId),
          ),
        );
      }
      return;
    }
    if (notification.kind == 'chat' || notification.kind == 'chat_request') {
      final conversationId = notification.data['conversation_id'];
      if (conversationId == null || conversationId.isEmpty) return;
      final conversation = await runWithAppLoading(
        context,
        message: 'Abrindo conversa…',
        action: () => ref
            .read(chatRealtimeCoordinatorProvider)
            .openConversation(conversationId),
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => conversation == null
              ? const ChatListPage()
              : ChatPage(conversation: conversation),
        ),
      );
    }
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
