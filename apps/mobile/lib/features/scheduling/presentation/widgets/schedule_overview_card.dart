import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../domain/entities/provider_schedule.dart';

class ScheduleOverviewCard extends StatelessWidget {
  const ScheduleOverviewCard({required this.schedule, super.key});

  final ProviderSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final activeDays = schedule.rules
        .map((rule) => rule.weekday)
        .toSet()
        .length;
    final minutes = schedule.rules.fold<int>(
      0,
      (total, rule) => total + rule.endMinute - rule.startMinute,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _OverviewIcon(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sua semana',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Defina quando clientes podem agendar',
                      style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  value: '$activeDays',
                  label: activeDays == 1 ? 'dia ativo' : 'dias ativos',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewMetric(
                  value: _duration(minutes),
                  label: 'por semana',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewMetric(
                  value: '${schedule.blocks.length}',
                  label: schedule.blocks.length == 1 ? 'bloqueio' : 'bloqueios',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewIcon extends StatelessWidget {
  const _OverviewIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: Colors.white.withValues(alpha: .18)),
    ),
    child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
  );
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10),
        ),
      ],
    ),
  );
}

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) return '${hours}h';
  return '${hours}h${remainder.toString().padLeft(2, '0')}';
}
