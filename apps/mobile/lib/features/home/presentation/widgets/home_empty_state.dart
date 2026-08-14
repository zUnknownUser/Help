import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    required this.needsLocation,
    this.onLocation,
    super.key,
  });

  final bool needsLocation;
  final VoidCallback? onLocation;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          needsLocation
              ? Icons.location_searching_rounded
              : Icons.search_off_rounded,
          size: 48,
          color: AppColors.primary,
        ),
        const SizedBox(height: 14),
        Text(
          needsLocation
              ? 'Encontre serviços perto de você'
              : 'Nenhum serviço disponível por aqui ainda',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(
          needsLocation
              ? 'Ative sua localização ou informe um CEP para ver profissionais da sua região.'
              : 'Novos profissionais aparecerão aqui assim que publicarem seus serviços.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        if (needsLocation) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onLocation,
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Usar minha localização'),
          ),
        ],
      ],
    ),
  );
}
