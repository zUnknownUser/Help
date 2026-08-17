import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../domain/entities/catalog_query.dart';
import '../../domain/entities/service_offer.dart';
import '../../data/providers/home_data_providers.dart';
import '../widgets/service_card.dart';
import '../../../service_details/presentation/pages/service_details_page.dart';

class ServiceDiscoveryPage extends ConsumerStatefulWidget {
  const ServiceDiscoveryPage({
    required this.title,
    required this.initialQuery,
    super.key,
  });

  final String title;
  final CatalogQuery initialQuery;

  @override
  ConsumerState<ServiceDiscoveryPage> createState() =>
      _ServiceDiscoveryPageState();
}

class _ServiceDiscoveryPageState extends ConsumerState<ServiceDiscoveryPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _items = <ServiceOffer>[];
  late CatalogQuery _query;
  Timer? _debounce;
  String _nextCursor = '';
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _search.text = _query.text;
    _scroll.addListener(_onScroll);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Serviço ou profissional',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Filtros',
                icon: const Icon(Icons.tune_rounded),
                onPressed: _openFilters,
              ),
            ),
          ),
        ),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (_loading) {
      return const AppLoadingView(message: 'Buscando serviços…');
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Nenhum serviço real disponível com esses filtros.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisExtent: 237,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, index) => index == _items.length
          ? const Center(child: AppProgressIndicator())
          : ServiceCard(
              key: ValueKey(_items[index].id),
              offer: _items[index],
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ServiceDetailsPage(
                    serviceId: _items[index].id,
                    preview: _items[index],
                  ),
                ),
              ),
            ),
    );
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = _query.copyWith(text: value, cursor: '');
      _load(reset: true);
    });
  }

  void _onScroll() {
    if (_nextCursor.isNotEmpty &&
        !_loadingMore &&
        _scroll.position.extentAfter < 500) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final request = _query.copyWith(cursor: reset ? '' : _nextCursor);
      final page = await ref
          .read(catalogRemoteDataSourceProvider)
          .search(request);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        final existing = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => existing.add(item.id)));
        _nextCursor = page.nextCursor;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openFilters() async {
    final next = await showModalBottomSheet<CatalogQuery>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CatalogFilters(query: _query),
    );
    if (next == null) return;
    _query = next.copyWith(text: _search.text, cursor: '');
    await _load(reset: true);
  }
}

class _CatalogFilters extends StatefulWidget {
  const _CatalogFilters({required this.query});
  final CatalogQuery query;

  @override
  State<_CatalogFilters> createState() => _CatalogFiltersState();
}

class _CatalogFiltersState extends State<_CatalogFilters> {
  late double _radius = widget.query.radiusKm;
  late double _rating = widget.query.minRating ?? 0;
  late bool _verified = widget.query.verified ?? false;
  late CatalogSort _sort = widget.query.sort;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Text('Distância: ${_radius.round()} km'),
          Slider(
            value: _radius,
            min: 5,
            max: 100,
            divisions: 19,
            onChanged: (value) => setState(() => _radius = value),
          ),
          Text('Avaliação mínima: ${_rating.toStringAsFixed(1)}'),
          Slider(
            value: _rating,
            min: 0,
            max: 5,
            divisions: 10,
            onChanged: (value) => setState(() => _rating = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Somente profissionais verificados'),
            value: _verified,
            onChanged: (value) => setState(() => _verified = value),
          ),
          DropdownButtonFormField<CatalogSort>(
            initialValue: _sort,
            decoration: const InputDecoration(labelText: 'Ordenar por'),
            items:
                const {
                      CatalogSort.distance: 'Mais perto',
                      CatalogSort.newest: 'Mais recentes',
                      CatalogSort.price: 'Menor preço',
                      CatalogSort.rating: 'Melhor avaliação',
                    }.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
            onChanged: (value) =>
                setState(() => _sort = value ?? CatalogSort.distance),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                widget.query.copyWith(
                  radiusKm: _radius,
                  minRating: _rating == 0 ? null : _rating,
                  verified: _verified ? true : null,
                  sort: _sort,
                ),
              ),
              child: const Text('Aplicar filtros'),
            ),
          ),
        ],
      ),
    ),
  );
}
