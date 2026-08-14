import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';

class HomeNavBar extends StatelessWidget {
  const HomeNavBar({
    this.onAccountTap,
    this.onConversationsTap,
    this.chatUnreadCount = 0,
    super.key,
  });

  final VoidCallback? onAccountTap;
  final VoidCallback? onConversationsTap;
  final int chatUnreadCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 69,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              children: [
                const _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Início',
                  selected: true,
                ),
                const _NavItem(
                  icon: Icons.calendar_month_outlined,
                  label: 'Pedidos',
                ),
                _NavItem(
                  icon: Icons.forum_outlined,
                  label: 'Conversas',
                  badgeCount: chatUnreadCount,
                  onTap: onConversationsTap,
                ),
                _NavItem(
                  key: const Key('home_account_button'),
                  icon: Icons.person_outline_rounded,
                  label: 'Conta',
                  onTap: onAccountTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badgeCount > 0,
                  label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                  child: Icon(icon, size: 21, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
