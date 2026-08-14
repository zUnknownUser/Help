import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/home_location.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.location,
    required this.searchPlaceholder,
    super.key,
  });

  final HomeLocation location;
  final String searchPlaceholder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              location.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        location.availabilityLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const _HeaderAction(icon: Icons.notifications_none_rounded),
                const SizedBox(width: 8),
                const _HeaderAction(icon: Icons.shopping_cart_outlined),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              height: 43,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8F7),
                border: Border.all(color: AppColors.outline),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 13),
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      searchPlaceholder,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: AppColors.textPrimary),
    );
  }
}
