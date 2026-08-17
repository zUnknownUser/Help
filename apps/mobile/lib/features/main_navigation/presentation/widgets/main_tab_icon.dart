import 'package:flutter/material.dart';

import '../main_tab.dart';

class MainTabIcon extends StatelessWidget {
  const MainTabIcon({
    required this.tab,
    required this.selected,
    required this.color,
    super.key,
  });

  final MainTab tab;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final asset = _asset(tab);
    if (asset != null) {
      return Image.asset(
        asset,
        width: 22,
        height: 22,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.high,
      );
    }
    return Icon(_materialIcon(tab, selected), size: 21, color: color);
  }
}

String? _asset(MainTab tab) => switch (tab) {
  MainTab.conversations => 'assets/icons/conversations.png',
  MainTab.account => 'assets/icons/profile.png',
  _ => null,
};

IconData _materialIcon(MainTab tab, bool selected) => switch (tab) {
  MainTab.home => selected ? Icons.home_rounded : Icons.home_outlined,
  MainTab.requests =>
    selected ? Icons.calendar_month_rounded : Icons.calendar_month_outlined,
  MainTab.conversations => Icons.forum_outlined,
  MainTab.account => Icons.person_outline_rounded,
};
