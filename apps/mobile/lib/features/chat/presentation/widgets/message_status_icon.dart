import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/chat_message.dart';

class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({required this.status, this.size = 14, super.key});
  final ChatMessageStatus status;
  final double size;

  @override
  Widget build(BuildContext context) => switch (status) {
    ChatMessageStatus.pending => Icon(
      Icons.schedule_rounded,
      size: size,
      color: AppColors.textSecondary,
    ),
    ChatMessageStatus.sent => Icon(
      Icons.check_rounded,
      size: size,
      color: AppColors.textSecondary,
    ),
    ChatMessageStatus.delivered => Icon(
      Icons.done_all_rounded,
      size: size,
      color: AppColors.textSecondary,
    ),
    ChatMessageStatus.read => Icon(
      Icons.done_all_rounded,
      size: size,
      color: AppColors.messageRead,
    ),
    ChatMessageStatus.failed => Icon(
      Icons.error_outline_rounded,
      size: size,
      color: AppColors.danger,
    ),
  };
}
