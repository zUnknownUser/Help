import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/provider_service.dart';
import '../../domain/entities/provider_workspace.dart';
import '../provider_failure_message.dart';
import '../providers/provider_workspace_providers.dart';
import '../validators/provider_service_validator.dart';
import '../widgets/provider_service_form_support.dart';

class ProviderServiceFormPage extends ConsumerStatefulWidget {
  const ProviderServiceFormPage({
    required this.categories,
    this.service,
    super.key,
  });

  final List<ProviderCategory> categories;
  final ProviderService? service;

  @override
  ConsumerState<ProviderServiceFormPage> createState() =>
      _ProviderServiceFormPageState();
}

class _ProviderServiceFormPageState
    extends ConsumerState<ProviderServiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _validator = const ProviderServiceValidator();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _oldPrice;
  late final TextEditingController _imageUrl;
  late String _categoryId;
  late bool _published;
  late bool _hasPromotion;
  late int _durationMinutes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _title = TextEditingController(text: service?.title ?? '');
    _description = TextEditingController(text: service?.description ?? '');
    _durationMinutes = service?.durationMinutes ?? 60;
    _price = TextEditingController(
      text: service == null
          ? ''
          : (service.priceCents / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    _oldPrice = TextEditingController(
      text: service?.oldPriceCents == null
          ? ''
          : (service!.oldPriceCents! / 100)
                .toStringAsFixed(2)
                .replaceAll('.', ','),
    );
    _hasPromotion = service?.oldPriceCents != null;
    _imageUrl = TextEditingController(text: service?.imageUrl ?? '');
    _categoryId = service?.categoryId ?? '';
    _published = service?.published ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _oldPrice.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(widget.service == null ? 'Novo serviço' : 'Editar serviço'),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProviderServiceFormIntro(),
                  const SizedBox(height: 24),
                  AppTextField(
                    fieldKey: const Key('provider_service_title'),
                    controller: _title,
                    label: 'Nome do serviço',
                    hint: 'Ex.: Limpeza residencial',
                    validator: _validator.title,
                    textInputAction: TextInputAction.next,
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _description,
                    label: 'Descrição',
                    hint: 'Explique claramente o que está incluso',
                    validator: _validator.description,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 1000,
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 16),
                  ProviderCategoryField(
                    categories: widget.categories,
                    value: _categoryId,
                    enabled: !_saving,
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 16),
                  ProviderDurationField(
                    value: _durationMinutes,
                    enabled: !_saving,
                    onChanged: (value) =>
                        setState(() => _durationMinutes = value),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _price,
                    label: _hasPromotion
                        ? 'Valor promocional (R\$)'
                        : 'Valor (R\$)',
                    validator: _validator.price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    enabled: !_saving,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Este serviço está em promoção',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'O preço anterior será exibido riscado.',
                    ),
                    value: _hasPromotion,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _hasPromotion = value;
                            if (!value) _oldPrice.clear();
                          }),
                  ),
                  if (_hasPromotion) ...[
                    AppTextField(
                      controller: _oldPrice,
                      label: 'Valor anterior (R\$)',
                      validator: (value) =>
                          _validator.oldPrice(value, currentPrice: _price.text),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _imageUrl,
                    label: 'URL da imagem (opcional)',
                    hint: 'https://...',
                    validator: _validator.imageUrl,
                    keyboardType: TextInputType.url,
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Publicar agora',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Serviços publicados podem aparecer para clientes próximos.',
                    ),
                    value: _published,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _published = value),
                  ),
                  const SizedBox(height: 22),
                  AppButton(
                    key: const Key('provider_service_save'),
                    label: widget.service == null
                        ? 'Cadastrar serviço'
                        : 'Salvar alterações',
                    isLoading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final failure = await ref
        .read(providerWorkspaceControllerProvider.notifier)
        .saveService(
          id: widget.service?.id,
          draft: ProviderServiceDraft(
            title: _title.text,
            description: _description.text,
            categoryId: _categoryId,
            durationMinutes: _durationMinutes,
            priceCents: _validator.priceInCents(_price.text),
            oldPriceCents: _hasPromotion
                ? _validator.priceInCents(_oldPrice.text)
                : null,
            imageUrl: _imageUrl.text,
            published: _published,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(providerFailureMessage(failure))));
      return;
    }
    Navigator.of(context).pop(true);
  }
}
