import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/chat_conversation.dart';
import 'chat_avatar.dart';
import 'message_status_icon.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    required this.onAvatarTap,
    this.onAccept,
    this.onDecline,
    this.deciding = false,
    super.key,
  });

  final ChatConversation conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool deciding;

  bool get _incomingRequest =>
      conversation.status == ChatConversationStatus.pending &&
      !conversation.requestedByMe;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAvatarTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ChatAvatar(name: conversation.otherDisplayName),
                      if (conversation.canMessage && conversation.otherOnline)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.otherDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            _time(conversation.updatedAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: conversation.unreadCount > 0
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (conversation.lastMessage?.senderId ==
                              currentUserId) ...[
                            MessageStatusIcon(
                              status: conversation.lastMessage!.status,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                          ] else if (!conversation.canMessage) ...[
                            Icon(
                              _statusIcon(conversation),
                              size: 14,
                              color: _incomingRequest
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              _preview(conversation),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _incomingRequest
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: _incomingRequest
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (conversation.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(count: conversation.unreadCount),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_incomingRequest) ...[
              const SizedBox(height: 11),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: deciding ? null : onDecline,
                    child: const Text('Recusar'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: deciding ? null : onAccept,
                    child: deciding
                        ? const AppProgressIndicator(
                            size: 17,
                            color: Colors.white,
                            semanticsLabel: 'Respondendo solicitação',
                          )
                        : const Text('Aceitar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.primary,
      shape: BoxShape.circle,
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

String _preview(ChatConversation conversation) {
  if (!conversation.canMessage) {
    return switch (conversation.status) {
      ChatConversationStatus.pending =>
        conversation.requestedByMe
            ? 'Aguardando a pessoa aceitar'
            : 'Quer iniciar uma conversa com você',
      ChatConversationStatus.declined => 'Solicitação não aceita',
      _ => '',
    };
  }
  final last = conversation.lastMessage;
  if (last == null) return 'Conversa aceita • diga olá';
  if (last.isDeleted) return 'Mensagem apagada';
  if (last.isVoice) return 'Mensagem de voz';
  return last.content;
}

IconData _statusIcon(ChatConversation conversation) =>
    switch (conversation.status) {
      ChatConversationStatus.pending =>
        conversation.requestedByMe
            ? Icons.schedule_rounded
            : Icons.mark_chat_unread_outlined,
      ChatConversationStatus.declined => Icons.block_rounded,
      _ => Icons.forum_outlined,
    };

String _time(DateTime value) {
  final now = DateTime.now();
  final local = value.toLocal();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}';
}
