import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/promotion.dart';
import '../icons/home_icon_resolver.dart';

class PromoFeatureLine extends StatelessWidget {
  const PromoFeatureLine({required this.feature, super.key});

  final PromotionFeature feature;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          HomeIconResolver.resolve(feature.iconKey),
          color: Colors.white,
          size: 13,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            feature.label,
            maxLines: 1,
            style: const TextStyle(fontSize: 9.5, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class PromoActionButton extends StatelessWidget {
  const PromoActionButton({
    required this.action,
    required this.onTap,
    super.key,
  });

  final PromotionAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = action.style == PromotionActionStyle.primary;
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            border: filled ? null : Border.all(color: Colors.white54),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                HomeIconResolver.resolve(action.iconKey),
                size: 13,
                color: filled ? AppColors.primary : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                action.label,
                style: TextStyle(
                  color: filled ? AppColors.primaryDark : Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
