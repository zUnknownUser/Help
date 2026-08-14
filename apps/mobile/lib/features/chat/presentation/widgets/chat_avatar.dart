import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({required this.name, this.radius = 22, super.key});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.primarySoft,
    foregroundColor: AppColors.primary,
    child: Text(
      _initials(name),
      style: const TextStyle(fontWeight: FontWeight.w900),
    ),
  );

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}
