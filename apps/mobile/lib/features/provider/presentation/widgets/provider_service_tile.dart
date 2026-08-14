import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/provider_service.dart';

enum ProviderServiceAction { edit, delete }

class ProviderServiceTile extends StatelessWidget {
  const ProviderServiceTile({
    required this.service,
    required this.onPublishedChanged,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ProviderService service;
  final ValueChanged<bool> onPublishedChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: service.published
                ? AppColors.primarySoft
                : AppColors.disabledSurface,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.home_repair_service_outlined,
            color: service.published
                ? AppColors.primaryDark
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  PopupMenuButton<ProviderServiceAction>(
                    padding: EdgeInsets.zero,
                    onSelected: (action) => switch (action) {
                      ProviderServiceAction.edit => onEdit(),
                      ProviderServiceAction.delete => onDelete(),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: ProviderServiceAction.edit,
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: ProviderServiceAction.delete,
                        child: Text('Excluir'),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${_money(service.priceCents)} • ${service.durationMinutes} min',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Status(published: service.published),
                  const Spacer(),
                  Transform.scale(
                    scale: .82,
                    child: Switch.adaptive(
                      value: service.published,
                      onChanged: onPublishedChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.published});
  final bool published;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: published ? AppColors.primarySoft : AppColors.disabledSurface,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      published ? 'Publicado' : 'Pausado',
      style: TextStyle(
        color: published ? AppColors.primaryDark : AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

String _money(int cents) =>
    'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';
