import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/chat_conversation.dart';
import '../formatters/chat_presence_label.dart';
import 'chat_avatar.dart';

Future<void> showChatContactSheet(
  BuildContext context,
  ChatConversation conversation, {
  VoidCallback? onOpenConversation,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => _ChatContactSheet(
    conversation: conversation,
    onOpenConversation: onOpenConversation,
  ),
);

class _ChatContactSheet extends StatelessWidget {
  const _ChatContactSheet({
    required this.conversation,
    this.onOpenConversation,
  });

  final ChatConversation conversation;
  final VoidCallback? onOpenConversation;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatAvatar(name: conversation.otherDisplayName, radius: 42),
        const SizedBox(height: 13),
        Text(
          conversation.otherDisplayName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          _contactStatus(conversation),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.primary),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'O Help protege os dados pessoais e registra as ações importantes da conversa.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onOpenConversation != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onOpenConversation!();
              },
              icon: const Icon(Icons.forum_rounded),
              label: const Text('Abrir conversa'),
            ),
          ),
        ],
      ],
    ),
  );
}

String _contactStatus(ChatConversation conversation) {
  if (!conversation.canMessage) {
    return switch (conversation.status) {
      ChatConversationStatus.pending =>
        conversation.requestedByMe
            ? 'Aguardando aceite'
            : 'Solicitação de conversa recebida',
      ChatConversationStatus.declined => 'Solicitação não aceita',
      _ => '',
    };
  }
  return chatLastSeenLabel(
    online: conversation.otherOnline,
    lastSeenAt: conversation.otherLastSeenAt,
  );
}
