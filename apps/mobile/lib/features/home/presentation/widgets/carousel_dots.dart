import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';

class CarouselDots extends StatelessWidget {
  const CarouselDots({required this.count, this.selectedIndex = 0, super.key});

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: index == selectedIndex ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: index == selectedIndex
                  ? AppColors.primary
                  : AppColors.outline,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}
