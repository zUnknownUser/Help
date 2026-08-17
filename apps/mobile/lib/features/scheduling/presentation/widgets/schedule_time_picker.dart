import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';

Future<int?> showScheduleTimePicker(
  BuildContext context, {
  required int selected,
  required int minimum,
  required int maximum,
  bool allowEndOfDay = false,
}) {
  final values = <int>[
    for (
      var minute = minimum + ((15 - minimum % 15) % 15);
      minute <= maximum;
      minute += 15
    )
      if (minute < 1440 || allowEndOfDay) minute,
  ];
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _TimePickerSheet(values: values, selected: selected),
  );
}

class _TimePickerSheet extends StatelessWidget {
  const _TimePickerSheet({required this.values, required this.selected});

  final List<int> values;
  final int selected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .58,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 2, 20, 14),
          child: Text(
            'Escolha o horário',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisExtent: 48,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: values.length,
            itemBuilder: (context, index) {
              final value = values[index];
              final isSelected = value == selected;
              return Material(
                color: isSelected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: () => Navigator.pop(context, value),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Center(
                    child: Text(
                      formatScheduleMinute(value),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

String formatScheduleMinute(int minute) {
  if (minute == 1440) return '24:00';
  return '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}
