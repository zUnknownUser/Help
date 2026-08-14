import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/home_location.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.location,
    required this.searchPlaceholder,
    required this.unreadNotificationCount,
    required this.onLocationTap,
    required this.onNotificationsTap,
    required this.onSearchTap,
    required this.onAccountTap,
    super.key,
  });

  final HomeLocation location;
  final String searchPlaceholder;
  final int unreadNotificationCount;
  final VoidCallback onLocationTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSearchTap;
  final VoidCallback onAccountTap;

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
                IconButton(
                  key: const Key('home_location_button'),
                  tooltip: 'Alterar endereço',
                  onPressed: onLocationTap,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.location_on_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
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
                              location.address.isEmpty
                                  ? 'Escolha seu endereço'
                                  : location.address,
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
                        location.availabilityLabel.isEmpty
                            ? 'Para ver serviços perto de você'
                            : location.availabilityLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeaderAction(
                  key: const Key('home_notifications_button'),
                  icon: Icons.notifications_none_rounded,
                  badgeCount: unreadNotificationCount,
                  onTap: onNotificationsTap,
                  tooltip: 'Notificações',
                ),
                const SizedBox(width: 8),
                _HeaderAction(
                  icon: Icons.person_outline_rounded,
                  onTap: onAccountTap,
                  tooltip: 'Minha conta',
                ),
              ],
            ),
            const SizedBox(height: 13),
            InkWell(
              key: const Key('home_search_button'),
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(11),
              child: Container(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox.square(
          dimension: 35,
          child: IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.outline),
            ),
            icon: Icon(icon, size: 18, color: AppColors.textPrimary),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
