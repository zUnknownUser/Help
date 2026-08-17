import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../home/domain/entities/home_location.dart';
import '../../../home/domain/entities/service_category.dart';
import '../providers/help_now_providers.dart';
import 'help_now_tracking_page.dart';

class HelpNowStartPage extends ConsumerStatefulWidget {
  const HelpNowStartPage({
    required this.categories,
    required this.location,
    super.key,
  });

  final List<ServiceCategory> categories;
  final HomeLocation location;

  static const acceptsUncategorized = true;

  @override
  ConsumerState<HelpNowStartPage> createState() => _HelpNowStartPageState();
}

class _HelpNowStartPageState extends ConsumerState<HelpNowStartPage> {
  final _note = TextEditingController();
  ServiceCategory? _selected;
  bool _sending = false;

  static const _general = ServiceCategory(
    id: '',
    name: 'Ajuda geral',
    iconKey: 'help',
  );

  @override
  void initState() {
    super.initState();
    if (widget.categories.isEmpty) _selected = _general;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Help Agora')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              const Text(
                'O que você precisa resolver?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Escolha a categoria e conte o essencial. Vamos procurar profissionais disponíveis perto de você.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [...widget.categories, _general]
                    .map(
                      (category) => ChoiceChip(
                        label: Text(category.name.replaceAll('\n', ' ')),
                        selected: _selected?.id == category.id,
                        onSelected: (_) => setState(() => _selected = category),
                        selectedColor: AppColors.primarySoft,
                        side: const BorderSide(color: AppColors.outline),
                        labelStyle: TextStyle(
                          color: _selected?.id == category.id
                              ? AppColors.primaryDark
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Descreva rapidamente (opcional)',
                  hintText: 'Ex.: vazamento forte embaixo da pia',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              _LocationTile(location: widget.location),
              const SizedBox(height: 16),
              const _SafetyNote(),
              const SizedBox(height: 24),
              AppButton(
                key: const Key('help_now_search_button'),
                label: 'Buscar profissional agora',
                leading: const Icon(Icons.radar_rounded, size: 19),
                isLoading: _sending,
                onPressed: _selected == null || _sending ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(customerHelpNowControllerProvider.notifier)
          .create(
            category: _selected!,
            location: widget.location,
            note: _note.text,
          );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => const HelpNowTrackingPage()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message(error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.location});
  final HomeLocation location;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.outline),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_on_rounded, color: AppColors.primary),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Local do atendimento',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                location.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.info_outline_rounded,
        size: 17,
        color: AppColors.textSecondary,
      ),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Para emergências médicas, policiais ou incêndios, procure o serviço público responsável.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

String _message(Object error) {
  final text = error.toString();
  if (text.contains('já possui')) return 'Você já possui uma busca ativa.';
  return 'Não foi possível iniciar a busca agora. Tente novamente.';
}
