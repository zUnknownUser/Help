import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/provider_schedule.dart';

class ScheduleWeekStrip extends StatelessWidget {
  const ScheduleWeekStrip({
    required this.selectedWeekday,
    required this.rules,
    required this.onSelected,
    super.key,
  });

  final int selectedWeekday;
  final List<AvailabilityRule> rules;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final active = rules.map((rule) => rule.weekday).toSet();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Escolha um dia',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++) ...[
                if (weekday > 0) const SizedBox(width: 5),
                Expanded(
                  child: _WeekdayButton(
                    weekday: weekday,
                    selected: weekday == selectedWeekday,
                    active: active.contains(weekday),
                    onTap: () => onSelected(weekday),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekdayButton extends StatelessWidget {
  const _WeekdayButton({
    required this.weekday,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final int weekday;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${_fullNames[weekday]}, ${active ? 'disponível' : 'indisponível'}',
    child: Material(
      key: Key('schedule_weekday_$weekday'),
      color: selected ? AppColors.primary : AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _shortNames[weekday],
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: active ? 1 : .42)
                      : active
                      ? AppColors.primary
                      : AppColors.disabled,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const _shortNames = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
const _fullNames = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];
