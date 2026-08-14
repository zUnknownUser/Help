import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/provider_service.dart';
import 'provider_service_tile.dart';

class ProviderServicesSection extends StatelessWidget {
  const ProviderServicesSection({
    required this.services,
    required this.onCreate,
    required this.onEdit,
    required this.onPublishedChanged,
    required this.onDelete,
    super.key,
  });

  final List<ProviderService> services;
  final VoidCallback onCreate;
  final ValueChanged<ProviderService> onEdit;
  final void Function(ProviderService, bool) onPublishedChanged;
  final ValueChanged<ProviderService> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Meus serviços',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          Text('${services.length} cadastrados'),
        ],
      ),
      const SizedBox(height: 10),
      if (services.isEmpty)
        _ServicesEmpty(onCreate: onCreate)
      else
        ...services.map(
          (service) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProviderServiceTile(
              key: ValueKey(service.id),
              service: service,
              onPublishedChanged: (value) => onPublishedChanged(service, value),
              onEdit: () => onEdit(service),
              onDelete: () => onDelete(service),
            ),
          ),
        ),
    ],
  );
}

class _ServicesEmpty extends StatelessWidget {
  const _ServicesEmpty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.add_business_outlined,
          color: AppColors.primary,
          size: 34,
        ),
        const SizedBox(height: 9),
        const Text(
          'Mostre aos clientes o que você faz',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cadastre seu primeiro serviço com valor e duração.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onCreate, child: const Text('Cadastrar agora')),
      ],
    ),
  );
}
