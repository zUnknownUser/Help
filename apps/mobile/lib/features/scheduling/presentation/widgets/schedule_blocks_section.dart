import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/provider_schedule.dart';
import 'schedule_block_formatters.dart';

class ScheduleBlocksSection extends StatelessWidget {
  const ScheduleBlocksSection({
    required this.schedule,
    required this.onAdd,
    required this.onDelete,
    super.key,
  });

  final ProviderSchedule schedule;
  final VoidCallback onAdd;
  final ValueChanged<ScheduleBlock> onDelete;

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
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pausas e bloqueios',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Folgas, viagens e compromissos',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (schedule.blocks.isEmpty)
          const _EmptyBlocks()
        else
          ...schedule.blocks.map(
            (block) => _BlockTile(block: block, onDelete: onDelete),
          ),
      ],
    ),
  );
}

class _EmptyBlocks extends StatelessWidget {
  const _EmptyBlocks();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: const Row(
      children: [
        Icon(Icons.event_available_rounded, color: AppColors.primary),
        SizedBox(width: 11),
        Expanded(
          child: Text(
            'Nenhum bloqueio. Sua rotina semanal está valendo normalmente.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.block, required this.onDelete});

  final ScheduleBlock block;
  final ValueChanged<ScheduleBlock> onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(
          Icons.event_busy_rounded,
          size: 19,
          color: AppColors.danger,
        ),
      ),
      title: Text(
        block.reason.isEmpty ? 'Indisponível' : block.reason,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${formatBlockDateTime(block.startsAt)} — '
        '${formatBlockDateTime(block.endsAt)}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: IconButton(
        tooltip: 'Remover bloqueio',
        onPressed: () => onDelete(block),
        icon: const Icon(Icons.close_rounded, size: 19),
      ),
    ),
  );
}
