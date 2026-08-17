import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../data/scheduling_providers.dart';
import '../../domain/entities/provider_schedule.dart';
import '../controllers/provider_schedule_controller.dart';
import '../widgets/schedule_block_sheet.dart';
import '../widgets/schedule_blocks_section.dart';
import '../widgets/schedule_day_card.dart';
import '../widgets/schedule_overview_card.dart';
import '../widgets/schedule_preferences.dart';
import '../widgets/schedule_week_strip.dart';

class ProviderSchedulePage extends ConsumerStatefulWidget {
  const ProviderSchedulePage({super.key});

  @override
  ConsumerState<ProviderSchedulePage> createState() =>
      _ProviderSchedulePageState();
}

class _ProviderSchedulePageState extends ConsumerState<ProviderSchedulePage> {
  late final ProviderScheduleController _controller;
  late int _selectedWeekday = DateTime.now().weekday % 7;

  @override
  void initState() {
    super.initState();
    _controller = ProviderScheduleController(
      ref.read(schedulingRepositoryProvider),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final hasSchedule = _controller.schedule != null;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Disponibilidade')),
        body: _body(),
        bottomNavigationBar: hasSchedule
            ? _SaveBar(saving: _controller.saving, onSave: _save)
            : null,
      );
    },
  );

  Widget _body() {
    if (_controller.loading && _controller.schedule == null) {
      return const AppLoadingView(message: 'Carregando disponibilidade…');
    }
    final schedule = _controller.schedule;
    if (schedule == null) {
      return _ErrorState(
        message: schedulingFailureMessage(_controller.failure),
        onRetry: _controller.load,
      );
    }
    final dayRules = schedule.rules
        .where((rule) => rule.weekday == _selectedWeekday)
        .toList(growable: false);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (_controller.loading)
            const AppLinearProgressIndicator(
              semanticsLabel: 'Atualizando disponibilidade',
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    ScheduleOverviewCard(schedule: schedule),
                    const SizedBox(height: 14),
                    ScheduleWeekStrip(
                      selectedWeekday: _selectedWeekday,
                      rules: schedule.rules,
                      onSelected: (weekday) =>
                          setState(() => _selectedWeekday = weekday),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      child: ScheduleDayCard(
                        key: ValueKey(_selectedWeekday),
                        weekday: _selectedWeekday,
                        rules: dayRules,
                        onChanged: (rules) =>
                            _controller.setRulesForDay(_selectedWeekday, rules),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SchedulePreferences(
                      schedule: schedule,
                      onChanged: _controller.updateSettings,
                    ),
                    const SizedBox(height: 14),
                    ScheduleBlocksSection(
                      schedule: schedule,
                      onAdd: _addBlock,
                      onDelete: _deleteBlock,
                    ),
                    if (_controller.failure != null) ...[
                      const SizedBox(height: 14),
                      _InlineError(
                        message: schedulingFailureMessage(_controller.failure),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (await _controller.save() && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Agenda atualizada.')));
    }
  }

  Future<void> _addBlock() async {
    final draft = await showScheduleBlockSheet(context);
    if (draft != null &&
        mounted &&
        await _controller.addBlock(draft) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Período bloqueado.')));
    }
  }

  Future<void> _deleteBlock(ScheduleBlock block) async {
    if (await _controller.deleteBlock(block.id) && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bloqueio removido.')));
    }
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.outline)),
    ),
    child: SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 528),
          child: AppButton(
            label: 'Salvar alterações',
            isLoading: saving,
            onPressed: saving ? null : onSave,
          ),
        ),
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.dangerSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
