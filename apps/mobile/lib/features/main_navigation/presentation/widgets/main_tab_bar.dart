import 'package:flutter/material.dart';

import '../../../../../core/design_system/foundations/app_colors.dart';
import '../main_tab.dart';
import 'main_tab_icon.dart';

class MainTabBar extends StatelessWidget {
  const MainTabBar({
    required this.selected,
    required this.onSelected,
    this.chatUnreadCount = 0,
    super.key,
  });

  final MainTab selected;
  final ValueChanged<MainTab> onSelected;
  final int chatUnreadCount;

  @override
  Widget build(BuildContext context) => SafeArea(
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
            children: MainTab.values
                .map(
                  (tab) => _TabItem(
                    tab: tab,
                    selected: tab == selected,
                    badgeCount: tab == MainTab.conversations
                        ? chatUnreadCount
                        : 0,
                    onTap: () => onSelected(tab),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    ),
  );
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final MainTab tab;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: _label(tab),
        child: InkWell(
          key: Key('main_tab_${tab.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.06 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Badge(
                      isLabelVisible: badgeCount > 0,
                      label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                      child: MainTabIcon(
                        tab: tab,
                        selected: selected,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _label(tab),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _label(MainTab tab) => switch (tab) {
  MainTab.home => 'Início',
  MainTab.requests => 'Pedidos',
  MainTab.conversations => 'Conversas',
  MainTab.account => 'Conta',
};
