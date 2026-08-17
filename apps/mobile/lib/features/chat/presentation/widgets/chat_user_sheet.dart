import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/chat_conversation.dart';
import 'chat_avatar.dart';
import 'chat_user_tile.dart';

Future<void> showChatUserSheet(
  BuildContext context,
  ChatUser user, {
  required VoidCallback onStart,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (sheetContext) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatAvatar(name: user.displayName, radius: 42),
        const SizedBox(height: 13),
        Text(
          user.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          chatUserRoleLabel(user.role),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Sem um serviço em comum, a outra pessoa precisa aceitar a solicitação antes das mensagens serem liberadas.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(sheetContext);
              onStart();
            },
            icon: const Icon(Icons.forum_rounded),
            label: const Text('Iniciar conversa'),
          ),
        ),
      ],
    ),
  ),
);
