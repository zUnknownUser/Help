import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/chat_conversation.dart';
import 'chat_avatar.dart';

class ConversationAccessView extends StatelessWidget {
  const ConversationAccessView({
    required this.conversation,
    required this.loading,
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  final ChatConversation conversation;
  final bool loading;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final pending = conversation.status == ChatConversationStatus.pending;
    final incoming = pending && !conversation.requestedByMe;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatAvatar(name: conversation.otherDisplayName, radius: 34),
                const SizedBox(height: 16),
                Text(
                  _title(conversation),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _description(conversation),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                if (incoming) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: AppColors.primaryDark,
                          size: 19,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Seu visto por último e as mensagens só serão liberados após o aceite.',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: 'Aceitar conversa',
                    isLoading: loading,
                    onPressed: loading ? null : onAccept,
                  ),
                  const SizedBox(height: 9),
                  AppButton(
                    label: 'Recusar',
                    variant: AppButtonVariant.outlined,
                    onPressed: loading ? null : onDecline,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _title(ChatConversation conversation) {
  if (conversation.status == ChatConversationStatus.declined) {
    return 'Solicitação não aceita';
  }
  return conversation.requestedByMe
      ? 'Solicitação enviada'
      : '${conversation.otherDisplayName} quer conversar';
}

String _description(ChatConversation conversation) {
  if (conversation.status == ChatConversationStatus.declined) {
    return 'Esta conversa não está disponível. Um contato relacionado a um pedido poderá ser liberado automaticamente.';
  }
  if (conversation.requestedByMe) {
    return 'Você poderá enviar mensagens assim que ${conversation.otherDisplayName} aceitar a solicitação.';
  }
  return 'Aceite somente se reconhecer a pessoa ou se quiser conversar antes de um serviço.';
}
