import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../home/presentation/widgets/service_offer_formatters.dart';
import '../../../scheduling/data/scheduling_providers.dart';
import '../../../scheduling/presentation/controllers/slot_pager.dart';
import '../../../scheduling/presentation/widgets/available_slots_picker.dart';
import '../../../service_requests/domain/entities/service_request_negotiation.dart';
import '../../domain/entities/service_details.dart';
import '../controllers/service_request_form_controller.dart';
import '../providers/service_details_providers.dart';
import 'service_request_fields.dart';

typedef RequestAttachmentUploader = Future<bool> Function(
  String requestId,
  String filePath,
);

class ServiceRequestSheet extends ConsumerStatefulWidget {
  const ServiceRequestSheet({
    required this.details,
    required this.attachmentUploader,
    super.key,
  });

  final ServiceDetails details;
  final RequestAttachmentUploader attachmentUploader;

  @override
  ConsumerState<ServiceRequestSheet> createState() =>
      _ServiceRequestSheetState();
}

class _ServiceRequestSheetState extends ConsumerState<ServiceRequestSheet> {
  final _note = TextEditingController();
  final _photos = <XFile>[];
  late final ServiceRequestFormController _form;
  late final SlotPager _slots;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _form = ServiceRequestFormController(
      serviceId: widget.details.offer.id,
      create: ref.read(createServiceRequestProvider),
    );
    _slots = SlotPager(
      repository: ref.read(schedulingRepositoryProvider),
      serviceId: widget.details.offer.id,
    )..load();
  }

  @override
  void dispose() {
    _note.dispose();
    _form.dispose();
    _slots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _form,
    builder: (context, _) => PopScope(
      canPop: !_form.submitting && !_uploading,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(child: _fields()),
        ),
      ),
    ),
  );

  Widget _fields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.outline,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Solicitar serviço',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 5),
      Text(
        widget.details.offer.title,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      ServiceRequestSelection(
        icon: Icons.calendar_month_outlined,
        label: 'Data e horário',
        value: _form.scheduledFor == null
            ? 'Escolha um horário disponível'
            : formatServiceSchedule(_form.scheduledFor!),
        onTap: _pickSchedule,
      ),
      const SizedBox(height: 10),
      ServiceRequestSelection(
        icon: Icons.location_on_outlined,
        label: widget.details.requestAddress!.label,
        value: widget.details.requestAddress!.formattedAddress,
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _note,
        label: 'Detalhes do serviço (opcional)',
        hint: 'Descreva o problema, medidas, acesso e outras informações úteis',
        minLines: 3,
        maxLines: 5,
        maxLength: 1000,
        enabled: !_form.submitting && !_uploading,
      ),
      const SizedBox(height: 16),
      _photoPicker(),
      if (_form.error case final error?) ...[
        const SizedBox(height: 8),
        Text(
          error,
          style: const TextStyle(color: AppColors.danger, fontSize: 12),
        ),
      ],
      const SizedBox(height: 14),
      _priceConfirmation(),
      const SizedBox(height: 16),
      AppButton(
        label: _uploading ? 'Enviando imagens…' : 'Confirmar solicitação',
        onPressed: _form.submitting || _uploading ? null : _submit,
        isLoading: _form.submitting || _uploading,
      ),
    ],
  );

  Widget _photoPicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Fotos do que precisa ser feito',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '${_photos.length}/$maximumServiceRequestAttachments',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      const SizedBox(height: 5),
      const Text(
        'Opcional. Imagens ajudam o profissional a entender o escopo e preparar um orçamento preciso.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 10),
      if (_photos.isNotEmpty) ...[
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_photos[index].path),
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 3,
                  top: 3,
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: _form.submitting || _uploading
                        ? null
                        : () => setState(() => _photos.removeAt(index)),
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton.icon(
        onPressed: _photos.length >= maximumServiceRequestAttachments ||
                _form.submitting ||
                _uploading
            ? null
            : _pickPhotos,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(_photos.isEmpty ? 'Selecionar fotos' : 'Adicionar mais'),
      ),
    ],
  );

  Widget _priceConfirmation() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Valor inicial',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Qualquer alteração exigirá seu aceite.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          formatMoney(widget.details.offer.priceCents),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    ),
  );

  Future<void> _pickSchedule() async {
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      builder: (_) => AvailableSlotsPicker(pager: _slots),
    );
    if (selected != null) _form.selectSchedule(selected);
  }

  Future<void> _pickPhotos() async {
    final selected = await ImagePicker().pickMultiImage(
      imageQuality: 84,
      maxWidth: 1800,
    );
    if (selected.isEmpty || !mounted) return;
    final existing = _photos.map((photo) => photo.path).toSet();
    setState(() {
      for (final photo in selected) {
        if (_photos.length >= maximumServiceRequestAttachments) break;
        if (existing.add(photo.path)) _photos.add(photo);
      }
    });
  }

  Future<void> _submit() async {
    final receipt = await _form.submit(_note.text);
    if (receipt == null && _form.error?.contains('horário') == true) {
      await _slots.load(reset: true);
    }
    if (receipt == null || !mounted) return;
    var failures = 0;
    if (_photos.isNotEmpty) {
      setState(() => _uploading = true);
      for (final photo in _photos) {
        if (!await widget.attachmentUploader(receipt.id, photo.path)) {
          failures++;
        }
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }
    if (mounted) {
      Navigator.pop(
        context,
        receipt.copyWith(attachmentUploadFailures: failures),
      );
    }
  }
}
