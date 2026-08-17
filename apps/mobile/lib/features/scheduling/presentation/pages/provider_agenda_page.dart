import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../service_requests/domain/entities/service_request_item.dart';
import '../../../service_requests/presentation/pages/service_request_details_page.dart';
import '../../../service_requests/presentation/providers/service_request_providers.dart';
import '../../../service_requests/presentation/widgets/service_request_tile.dart';

class ProviderAgendaPage extends ConsumerStatefulWidget {
  const ProviderAgendaPage({super.key});

  @override
  ConsumerState<ProviderAgendaPage> createState() => _ProviderAgendaPageState();
}

class _ProviderAgendaPageState extends ConsumerState<ProviderAgendaPage> {
  late DateTime _week = _startOfWeek(DateTime.now());
  List<ServiceRequestItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Minha agenda')),
    body: Column(
      children: [
        _WeekPicker(
          week: _week,
          onPrevious: () => _move(-7),
          onNext: () => _move(7),
          onToday: () {
            setState(() => _week = _startOfWeek(DateTime.now()));
            _load();
          },
        ),
        if (_loading && _items.isNotEmpty)
          const AppLinearProgressIndicator(
            semanticsLabel: 'Atualizando agenda',
          ),
        Expanded(child: _content()),
      ],
    ),
  );

  Widget _content() {
    if (_loading && _items.isEmpty) {
      return const AppLoadingView(message: 'Carregando sua agenda…');
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum atendimento nesta semana.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final groups = <DateTime, List<ServiceRequestItem>>{};
    for (final item in _items) {
      final value = item.scheduledFor.toLocal();
      final day = DateTime(value.year, value.month, value.day);
      groups.putIfAbsent(day, () => []).add(item);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: groups.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _day(entry.key),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    ...entry.value.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: ServiceRequestTile(
                          request: item,
                          onTap: () => _open(item),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(serviceRequestActionsProvider)
        .agenda(from: _week, to: _week.add(const Duration(days: 7)));
    if (!mounted) return;
    result.fold(
      onSuccess: (items) => setState(() {
        _items = items;
        _loading = false;
      }),
      onFailure: (failure) => setState(() {
        _error = failure.message ?? 'Não foi possível carregar sua agenda.';
        _loading = false;
      }),
    );
  }

  void _move(int days) {
    setState(() => _week = _week.add(Duration(days: days)));
    _load();
  }

  Future<void> _open(ServiceRequestItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ServiceRequestDetailsPage(requestId: item.id, initial: item),
      ),
    );
    if (mounted) await _load();
  }
}

class _WeekPicker extends StatelessWidget {
  const _WeekPicker({
    required this.week,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime week;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Semana anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${_short(week)} — ${_short(week.add(const Duration(days: 6)))}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextButton(onPressed: onToday, child: const Text('Ir para hoje')),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Próxima semana',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

DateTime _startOfWeek(DateTime value) {
  final local = value.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _short(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

String _day(DateTime value) {
  const names = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  return '${names[value.weekday - 1]}, ${_short(value)}';
}
