import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/provider_schedule.dart';

typedef SchedulePreferencesChanged =
    void Function({int? notice, int? horizon, int? buffer, int? interval});

class SchedulePreferences extends StatelessWidget {
  const SchedulePreferences({
    required this.schedule,
    required this.onChanged,
    super.key,
  });

  final ProviderSchedule schedule;
  final SchedulePreferencesChanged onChanged;

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
        const _SectionHeader(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PreferenceTile(
                  width: width,
                  icon: Icons.notifications_active_outlined,
                  label: 'Antecedência',
                  value: _noticeLabel(schedule.minimumNoticeMinutes),
                  onTap: () => _choose(
                    context,
                    title: 'Antecedência mínima',
                    selected: schedule.minimumNoticeMinutes,
                    values: const [15, 30, 60, 120, 240, 1440],
                    label: _noticeLabel,
                    onSelected: (value) => onChanged(notice: value),
                  ),
                ),
                _PreferenceTile(
                  width: width,
                  icon: Icons.hourglass_bottom_rounded,
                  label: 'Entre serviços',
                  value: _minuteLabel(schedule.bufferMinutes),
                  onTap: () => _choose(
                    context,
                    title: 'Intervalo entre serviços',
                    selected: schedule.bufferMinutes,
                    values: const [0, 15, 30, 45, 60],
                    label: _minuteLabel,
                    onSelected: (value) => onChanged(buffer: value),
                  ),
                ),
                _PreferenceTile(
                  width: width,
                  icon: Icons.event_available_outlined,
                  label: 'Agenda aberta',
                  value: '${schedule.bookingHorizonDays} dias',
                  onTap: () => _choose(
                    context,
                    title: 'Até quando podem agendar',
                    selected: schedule.bookingHorizonDays,
                    values: const [15, 30, 60, 90, 180],
                    label: (value) => '$value dias',
                    onSelected: (value) => onChanged(horizon: value),
                  ),
                ),
                _PreferenceTile(
                  width: width,
                  icon: Icons.grid_view_rounded,
                  label: 'Grade de horários',
                  value: '${schedule.slotIntervalMinutes} min',
                  onTap: () => _choose(
                    context,
                    title: 'Intervalo da grade',
                    selected: schedule.slotIntervalMinutes,
                    values: const [15, 30, 60],
                    label: (value) => '$value min',
                    onSelected: (value) => onChanged(interval: value),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

Future<void> _choose(
  BuildContext context, {
  required String title,
  required int selected,
  required List<int> values,
  required String Function(int) label,
  required ValueChanged<int> onSelected,
}) async {
  final value = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ),
          ...values.map(
            (item) => ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              leading: Icon(
                item == selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: item == selected
                    ? AppColors.primary
                    : AppColors.disabled,
              ),
              title: Text(
                label(item),
                style: TextStyle(
                  fontWeight: item == selected
                      ? FontWeight.w900
                      : FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(context, item),
            ),
          ),
        ],
      ),
    ),
  );
  if (value != null && value != selected) onSelected(value);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.tune_rounded, color: AppColors.primary, size: 21),
      SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preferências de agendamento',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 2),
            Text(
              'Toque em uma opção para alterar',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(height: 13),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _minuteLabel(int value) => value == 0 ? 'Sem intervalo' : '$value min';

String _noticeLabel(int value) {
  if (value == 1440) return '1 dia antes';
  if (value >= 60) return '${value ~/ 60}h antes';
  return '$value min antes';
}
