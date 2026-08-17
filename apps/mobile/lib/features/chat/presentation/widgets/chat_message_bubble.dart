import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import 'message_status_icon.dart';
import 'voice_message_player.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.mine,
    this.onRetry,
    this.onLongPress,
    super.key,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onRetry;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: GestureDetector(
      onTap: onRetry,
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(11, 8, 8, 6),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFDDF2E3) : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: _content()),
            const SizedBox(width: 8),
            if (message.isEdited) ...[
              const Text(
                'editada',
                style: TextStyle(fontSize: 8, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              _time(message.displayedAt),
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
            if (mine) ...[
              const SizedBox(width: 3),
              MessageStatusIcon(status: message.status, size: 13),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _content() => message.isDeleted
      ? const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 15, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Mensagem apagada',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        )
      : message.isVoice
      ? VoiceMessagePlayer(message: message, mine: mine)
      : Text(
          message.content,
          style: const TextStyle(fontSize: 14, height: 1.3),
        );

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
