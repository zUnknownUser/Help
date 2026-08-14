import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/home_benefit.dart';
import '../icons/home_icon_resolver.dart';

class BenefitsStrip extends StatelessWidget {
  const BenefitsStrip({required this.benefits, super.key});

  final List<HomeBenefit> benefits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF9),
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: benefits
            .take(4)
            .map(
              (benefit) => _Benefit(
                icon: HomeIconResolver.resolve(benefit.iconKey),
                label: benefit.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 21, color: AppColors.primaryDark),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8.5,
              height: 1.15,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
