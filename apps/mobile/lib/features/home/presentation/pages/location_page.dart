import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/home_location.dart';
import '../../domain/services/location_resolver.dart';
import '../providers/home_providers.dart';
import '../../data/providers/home_data_providers.dart';

class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({required this.current, super.key});

  final HomeLocation current;

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  final _formKey = GlobalKey<FormState>();
  final _postalCode = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  String _label = 'Casa';
  bool _resolving = false;
  String? _error;

  @override
  void dispose() {
    _postalCode.dispose();
    _number.dispose();
    _complement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(homeActionControllerProvider).isLoading;
    final loading = saving || _resolving;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Sua localização')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.my_location_rounded,
                      size: 42,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Encontre serviços realmente perto de você',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Use o GPS do aparelho ou escolha outro local pelo CEP. O endereço completo não precisa ser digitado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (widget.current.address.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _CurrentLocation(address: widget.current.address),
                    ],
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Usar minha localização atual',
                      leading: const Icon(Icons.gps_fixed_rounded, size: 18),
                      isLoading: loading,
                      onPressed: loading ? null : _useCurrent,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ou altere pelo CEP',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _label,
                      decoration: const InputDecoration(
                        labelText: 'Identificação',
                      ),
                      items: const ['Casa', 'Trabalho', 'Outro endereço']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: loading
                          ? null
                          : (value) => setState(() => _label = value ?? 'Casa'),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _postalCode,
                      label: 'CEP',
                      hint: '00000-000',
                      prefixIcon: const Icon(Icons.location_searching_rounded),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          (value ?? '').replaceAll(RegExp(r'\D'), '').length ==
                              8
                          ? null
                          : 'Informe um CEP com 8 números.',
                      enabled: !loading,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: _number,
                            label: 'Número',
                            hint: '123',
                            keyboardType: TextInputType.streetAddress,
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Informe o número.'
                                : null,
                            enabled: !loading,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: AppTextField(
                            controller: _complement,
                            label: 'Complemento',
                            hint: 'Opcional',
                            enabled: !loading,
                          ),
                        ),
                      ],
                    ),
                    if (_error case final error?) ...[
                      const SizedBox(height: 12),
                      Text(
                        error,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Buscar CEP e usar endereço',
                      variant: AppButtonVariant.outlined,
                      isLoading: loading,
                      onPressed: loading ? null : _usePostalCode,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _useCurrent() async {
    await _resolve(() => ref.read(locationResolverProvider).current());
  }

  Future<void> _usePostalCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _resolve(
      () => ref
          .read(locationResolverProvider)
          .fromPostalCode(
            postalCode: _postalCode.text,
            number: _number.text,
            complement: _complement.text,
            label: _label,
          ),
    );
  }

  Future<void> _resolve(Future<HomeLocation> Function() operation) async {
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      final location = await operation();
      final saved = await ref
          .read(homeActionControllerProvider.notifier)
          .saveLocation(location);
      if (saved && mounted) Navigator.of(context).pop(true);
      if (!saved && mounted) {
        setState(() => _error = 'Não foi possível salvar a localização.');
      }
    } on LocationResolutionException catch (error) {
      if (mounted) setState(() => _error = _message(error.code));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  String _message(LocationResolutionError error) => switch (error) {
    LocationResolutionError.permissionDenied =>
      'Permita o acesso à localização para usar o GPS.',
    LocationResolutionError.permissionDeniedForever =>
      'A localização foi bloqueada. Libere a permissão nas configurações do aparelho.',
    LocationResolutionError.serviceDisabled =>
      'Ative a localização do aparelho e tente novamente.',
    LocationResolutionError.postalCodeNotFound =>
      'CEP não encontrado. Confira os números informados.',
    LocationResolutionError.unavailable =>
      'Não foi possível resolver esse local agora.',
  };
}

class _CurrentLocation extends StatelessWidget {
  const _CurrentLocation({required this.address});
  final String address;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_on_rounded, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
