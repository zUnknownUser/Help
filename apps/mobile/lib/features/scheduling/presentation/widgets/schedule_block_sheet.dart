import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/provider_schedule.dart';
import 'schedule_block_formatters.dart';

Future<ScheduleBlockDraft?> showScheduleBlockSheet(BuildContext context) =>
    showModalBottomSheet<ScheduleBlockDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _BlockSheet(),
    );

class _BlockSheet extends StatefulWidget {
  const _BlockSheet();

  @override
  State<_BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<_BlockSheet> {
  late DateTime _start = DateTime.now().add(const Duration(days: 1));
  late DateTime _end = _start.add(const Duration(hours: 2));
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      2,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bloquear período',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Clientes não poderão reservar dentro deste intervalo.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DateTimeCard(
                  label: 'Início',
                  value: _start,
                  onTap: () => _pick(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateTimeCard(
                  label: 'Fim',
                  value: _end,
                  onTap: () => _pick(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Ex.: viagem, consulta, folga',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Confirmar bloqueio',
            onPressed: _end.isAfter(_start) ? _submit : null,
          ),
        ],
      ),
    ),
  );

  void _submit() => Navigator.pop(
    context,
    ScheduleBlockDraft(
      startsAt: _start,
      endsAt: _end,
      reason: _reason.text.trim(),
    ),
  );

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _start = value;
        if (!_end.isAfter(value)) _end = value.add(const Duration(hours: 2));
      } else {
        _end = value;
      }
    });
  }
}

class _DateTimeCard extends StatelessWidget {
  const _DateTimeCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatBlockDateTime(value),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    ),
  );
}
