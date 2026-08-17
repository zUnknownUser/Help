import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../data/realtime/chat_realtime_coordinator.dart';
import '../formatters/chat_presence_label.dart';
import 'chat_avatar.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    required this.name,
    required this.presence,
    required this.connection,
    required this.typing,
    this.onTap,
    super.key,
  });

  final String name;
  final PresenceEvent presence;
  final RealtimeConnectionStatus connection;
  final bool typing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          ChatAvatar(name: name, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  chatPresenceLabel(
                    presence: presence,
                    connection: connection,
                    typing: typing,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: typing || presence.online
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
