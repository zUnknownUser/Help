import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/provider_schedule.dart';
import 'schedule_time_picker.dart';

class SchedulePeriodEditor extends StatelessWidget {
  const SchedulePeriodEditor({
    required this.index,
    required this.rule,
    required this.minimumStart,
    required this.maximumEnd,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  final int index;
  final AvailabilityRule rule;
  final int minimumStart;
  final int maximumEnd;
  final ValueChanged<AvailabilityRule> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Período ${index + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Remover período',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: 'Início',
                value: rule.startMinute,
                onTap: () => _pickStart(context),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: AppColors.textSecondary,
              ),
            ),
            Expanded(
              child: _TimeButton(
                label: 'Fim',
                value: rule.endMinute,
                onTap: () => _pickEnd(context),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _pickStart(BuildContext context) async {
    final value = await showScheduleTimePicker(
      context,
      selected: rule.startMinute,
      minimum: minimumStart,
      maximum: rule.endMinute - 30,
    );
    if (value != null) onChanged(rule.copyWith(startMinute: value));
  }

  Future<void> _pickEnd(BuildContext context) async {
    final value = await showScheduleTimePicker(
      context,
      selected: rule.endMinute,
      minimum: rule.startMinute + 30,
      maximum: maximumEnd,
      allowEndOfDay: true,
    );
    if (value != null) onChanged(rule.copyWith(endMinute: value));
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 17,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    formatScheduleMinute(value),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
