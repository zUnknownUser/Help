import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/provider_schedule.dart';
import 'schedule_period_editor.dart';
import 'schedule_time_picker.dart';

class ScheduleDayCard extends StatelessWidget {
  const ScheduleDayCard({
    required this.weekday,
    required this.rules,
    required this.onChanged,
    super.key,
  });

  final int weekday;
  final List<AvailabilityRule> rules;
  final ValueChanged<List<AvailabilityRule>> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayHeader(weekday: weekday, rules: rules, onToggle: _toggle),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: rules.isEmpty
              ? const _UnavailableHint()
              : Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    children: [
                      for (final entry in rules.asMap().entries)
                        SchedulePeriodEditor(
                          index: entry.key,
                          rule: entry.value,
                          minimumStart: entry.key == 0
                              ? 0
                              : rules[entry.key - 1].endMinute,
                          maximumEnd: entry.key == rules.length - 1
                              ? 1440
                              : rules[entry.key + 1].startMinute,
                          onChanged: (rule) => _replace(entry.key, rule),
                          onDelete: () => _delete(entry.key),
                        ),
                      if (rules.length < 3) ...[
                        const SizedBox(height: 2),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _canAdd ? _add : null,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Adicionar outro período'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    ),
  );

  bool get _canAdd => rules.isNotEmpty && rules.last.endMinute <= 1380;

  void _toggle(bool enabled) => onChanged(
    enabled
        ? [
            AvailabilityRule(
              weekday: weekday,
              startMinute: 480,
              endMinute: 1080,
            ),
          ]
        : const [],
  );

  void _replace(int index, AvailabilityRule rule) =>
      onChanged([...rules]..[index] = rule);

  void _delete(int index) => onChanged([...rules]..removeAt(index));

  void _add() {
    final start = rules.last.endMinute;
    onChanged([
      ...rules,
      AvailabilityRule(
        weekday: weekday,
        startMinute: start,
        endMinute: (start + 240).clamp(start + 60, 1440),
      ),
    ]);
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.weekday,
    required this.rules,
    required this.onToggle,
  });

  final int weekday;
  final List<AvailabilityRule> rules;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        alignment: Alignment.center,
        child: Text(
          _shortNames[weekday],
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _weekdays[weekday],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              rules.isEmpty ? 'Sem atendimento' : _summary(rules),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      Switch(
        key: const Key('schedule_day_toggle'),
        value: rules.isNotEmpty,
        onChanged: onToggle,
      ),
    ],
  );
}

class _UnavailableHint extends StatelessWidget {
  const _UnavailableHint();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: const Row(
      children: [
        Icon(Icons.nightlight_round, size: 18, color: AppColors.textSecondary),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Clientes não verão horários neste dia.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

String _summary(List<AvailabilityRule> rules) => rules
    .map(
      (rule) =>
          '${formatScheduleMinute(rule.startMinute)}–'
          '${formatScheduleMinute(rule.endMinute)}',
    )
    .join('  •  ');

const _shortNames = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
const _weekdays = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];
