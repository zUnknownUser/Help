import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../controllers/provider_schedule_controller.dart';
import '../controllers/slot_pager.dart';

class AvailableSlotsPicker extends StatelessWidget {
  const AvailableSlotsPicker({required this.pager, super.key});
  final SlotPager pager;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pager,
    builder: (context, _) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escolha um horário',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mostramos somente horários livres na agenda do prestador.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Flexible(child: _content(context)),
          ],
        ),
      ),
    ),
  );

  Widget _content(BuildContext context) {
    if (pager.loading && pager.slots.isEmpty) {
      return const AppLoadingView(
        message: 'Buscando horários livres…',
        compact: true,
      );
    }
    if (pager.failure != null && pager.slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              schedulingFailureMessage(pager.failure),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => pager.load(reset: true),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (pager.slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'Não há horários disponíveis no momento.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final groups = <DateTime, List<DateTime>>{};
    for (final slot in pager.slots) {
      final day = DateTime(slot.year, slot.month, slot.day);
      groups.putIfAbsent(day, () => []).add(slot);
    }
    return ListView(
      shrinkWrap: true,
      children: [
        ...groups.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _day(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.value
                      .map(
                        (slot) => ActionChip(
                          label: Text(_time(slot)),
                          onPressed: () => Navigator.pop(context, slot),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        if (pager.canLoadMore)
          Center(
            child: TextButton(
              onPressed: pager.loading ? null : pager.load,
              child: pager.loading
                  ? const AppProgressIndicator(
                      size: 18,
                      semanticsLabel: 'Buscando mais horários',
                    )
                  : const Text('Ver mais horários'),
            ),
          ),
      ],
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _day(DateTime value) {
  const weekdays = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} • ${weekdays[value.weekday - 1]}';
}
