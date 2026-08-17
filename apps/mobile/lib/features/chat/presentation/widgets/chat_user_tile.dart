import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/chat_conversation.dart';
import 'chat_avatar.dart';

class ChatUserTile extends StatelessWidget {
  const ChatUserTile({
    required this.user,
    required this.onOpen,
    required this.onView,
    this.loading = false,
    super.key,
  });

  final ChatUser user;
  final VoidCallback? onOpen;
  final VoidCallback onView;
  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: loading ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onView,
                child: ChatAvatar(name: user.displayName, radius: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _roleLabel(user.role),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const AppProgressIndicator(
                  size: 20,
                  semanticsLabel: 'Abrindo conversa',
                )
              else
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

String chatUserRoleLabel(ChatUserRole role) => _roleLabel(role);

String _roleLabel(ChatUserRole role) => switch (role) {
  ChatUserRole.provider => 'Profissional verificado',
  ChatUserRole.customer => 'Cliente com solicitação',
};
