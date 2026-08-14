import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/provider_workspace.dart';

class ProviderServiceFormIntro extends StatelessWidget {
  const ProviderServiceFormIntro({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.storefront_rounded, color: AppColors.primaryDark),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Use informações objetivas. Você poderá pausar ou editar o serviço quando quiser.',
            style: TextStyle(color: AppColors.primaryDark, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class ProviderCategoryField extends StatelessWidget {
  const ProviderCategoryField({
    required this.categories,
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final List<ProviderCategory> categories;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: categories.any((item) => item.id == value) ? value : '',
    decoration: const InputDecoration(labelText: 'Categoria'),
    items: [
      const DropdownMenuItem(value: '', child: Text('Sem categoria')),
      ...categories.map(
        (category) =>
            DropdownMenuItem(value: category.id, child: Text(category.name)),
      ),
    ],
    onChanged: enabled ? (next) => onChanged(next ?? '') : null,
  );
}
