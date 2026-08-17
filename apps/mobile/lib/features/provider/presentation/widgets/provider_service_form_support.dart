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

class ProviderDurationField extends StatelessWidget {
  const ProviderDurationField({
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tempo estimado',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              _durationLabel(value),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [30, 60, 90, 120]
              .map(
                (minutes) => ChoiceChip(
                  label: Text(_durationLabel(minutes)),
                  selected: value == minutes,
                  onSelected: enabled ? (_) => onChanged(minutes) : null,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: enabled ? () => _customDuration(context) : null,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Personalizar duração'),
        ),
      ],
    ),
  );

  Future<void> _customDuration(BuildContext context) async {
    var hours = value ~/ 60;
    var minutes = value % 60;
    minutes = (minutes / 5).round() * 5;
    if (minutes == 60) {
      hours++;
      minutes = 0;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Quanto tempo costuma levar?',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: hours,
                        decoration: const InputDecoration(labelText: 'Horas'),
                        items: List.generate(
                          25,
                          (index) => DropdownMenuItem(
                            value: index,
                            child: Text('$index'),
                          ),
                        ),
                        onChanged: (next) =>
                            setModalState(() => hours = next ?? 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: minutes,
                        decoration: const InputDecoration(labelText: 'Minutos'),
                        items: List.generate(12, (index) => index * 5)
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text('$item'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (next) =>
                            setModalState(() => minutes = next ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: hours * 60 + minutes < 15
                      ? null
                      : () => Navigator.pop(context, hours * 60 + minutes),
                  child: const Text('Usar esta duração'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) onChanged(selected);
  }
}

String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}min';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}min';
}
