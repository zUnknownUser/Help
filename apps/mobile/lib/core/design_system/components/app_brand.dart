import 'package:flutter/material.dart';

import '../foundations/app_colors.dart';
import '../foundations/app_radius.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.handyman_rounded,
            size: compact ? 19 : 22,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Help',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: compact ? 19 : 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
      ],
    );
  }
}
