import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/user_role.dart';

class RoleSelector extends StatelessWidget {
  const RoleSelector({
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  final UserRole? selected;
  final ValueChanged<UserRole> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoleCard(
          key: const Key('customer_role_card'),
          title: 'Quero contratar serviços',
          subtitle: 'Encontre profissionais e acompanhe seus pedidos.',
          icon: Icons.search_rounded,
          selected: selected == UserRole.customer,
          onTap: enabled ? () => onSelected(UserRole.customer) : null,
        ),
        const SizedBox(height: 10),
        _RoleCard(
          key: const Key('provider_role_card'),
          title: 'Quero oferecer serviços',
          subtitle: 'Crie seu perfil profissional e receba oportunidades.',
          icon: Icons.handyman_outlined,
          selected: selected == UserRole.provider,
          onTap: enabled ? () => onSelected(UserRole.provider) : null,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: selected
                    ? AppColors.primary
                    : AppColors.disabledSurface,
                foregroundColor: selected
                    ? Colors.white
                    : AppColors.textSecondary,
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.disabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
