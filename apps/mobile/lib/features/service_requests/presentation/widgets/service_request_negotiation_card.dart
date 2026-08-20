import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/service_request_item.dart';
import '../../domain/entities/service_request_negotiation.dart';
import '../providers/service_request_providers.dart';
import 'service_request_tile.dart';

class ServiceRequestNegotiationCard extends StatelessWidget {
  const ServiceRequestNegotiationCard({
    required this.request,
    required this.negotiation,
    required this.loading,
    required this.acting,
    required this.onRetry,
    required this.onPropose,
    required this.onAccept,
    required this.onAddAttachment,
    required this.onDeleteAttachment,
    super.key,
  });

  final ServiceRequestItem request;
  final ServiceRequestNegotiation? negotiation;
  final bool loading;
  final bool acting;
  final VoidCallback onRetry;
  final ValueChanged<ServiceQuote?> onPropose;
  final ValueChanged<ServiceQuote> onAccept;
  final VoidCallback onAddAttachment;
  final ValueChanged<ServiceRequestAttachment> onDeleteAttachment;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.request_quote_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Fotos e orçamento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Registre os detalhes e combine qualquer mudança de valor antes do serviço começar.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 15),
        if (loading && negotiation == null)
          const LinearProgressIndicator(minHeight: 2)
        else if (negotiation == null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Carregar negociação'),
          )
        else ...[
          _AttachmentSection(
            negotiation: negotiation!,
            acting: acting,
            onAdd: onAddAttachment,
            onDelete: onDeleteAttachment,
          ),
          const SizedBox(height: 18),
          _QuoteSection(
            request: request,
            negotiation: negotiation!,
            acting: acting,
            onPropose: onPropose,
            onAccept: onAccept,
          ),
        ],
      ],
    ),
  );
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.negotiation,
    required this.acting,
    required this.onAdd,
    required this.onDelete,
  });

  final ServiceRequestNegotiation negotiation;
  final bool acting;
  final VoidCallback onAdd;
  final ValueChanged<ServiceRequestAttachment> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Imagens do atendimento',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (negotiation.canAddAttachment)
            TextButton.icon(
              onPressed: acting ? null : onAdd,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Adicionar'),
            ),
        ],
      ),
      if (negotiation.attachments.isEmpty)
        const Text(
          'Adicione fotos para reduzir dúvidas e deixar o orçamento mais preciso.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        )
      else
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: negotiation.attachments.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (_, index) {
              final attachment = negotiation.attachments[index];
              return _AttachmentTile(
                attachment: attachment,
                onDelete: attachment.canDelete && !acting
                    ? () => onDelete(attachment)
                    : null,
              );
            },
          ),
        ),
    ],
  );
}

class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile({required this.attachment, this.onDelete});

  final ServiceRequestAttachment attachment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(
      serviceRequestAttachmentBytesProvider(attachment.id),
    );
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Material(
                      color: AppColors.background,
                      child: InkWell(
                        onTap: image.value == null
                            ? null
                            : () => _preview(context, image.value!),
                        child: image.when(
                          data: (bytes) => Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            cacheWidth: 336,
                            gaplessPlayback: true,
                          ),
                          loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (onDelete != null)
                  Positioned(
                    right: 3,
                    top: 3,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remover imagem',
                      onPressed: onDelete,
                      icon: const Icon(Icons.close_rounded, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            attachment.caption.isEmpty
                ? attachment.uploaderName
                : attachment.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _preview(BuildContext context, List<int> bytes) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          minScale: .8,
          maxScale: 4,
          child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _QuoteSection extends StatelessWidget {
  const _QuoteSection({
    required this.request,
    required this.negotiation,
    required this.acting,
    required this.onPropose,
    required this.onAccept,
  });

  final ServiceRequestItem request;
  final ServiceRequestNegotiation negotiation;
  final bool acting;
  final ValueChanged<ServiceQuote?> onPropose;
  final ValueChanged<ServiceQuote> onAccept;

  @override
  Widget build(BuildContext context) {
    final latest = negotiation.latestQuote;
    if (latest == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            request.viewerRole == RequestViewerRole.provider
                ? 'O preço inicial é ${formatRequestPrice(request.quotedPriceCents)}. Envie uma proposta se o escopo exigir ajustes.'
                : 'O valor inicial continua válido. Se o escopo mudar, o profissional pode enviar um orçamento detalhado.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (negotiation.canPropose) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Enviar orçamento detalhado',
              variant: AppButtonVariant.outlined,
              onPressed: acting ? null : () => onPropose(null),
            ),
          ],
        ],
      );
    }
    final sentByViewer = latest.authorRole == request.viewerRole;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuoteCard(quote: latest, highlighted: true),
        if (latest.isPending && sentByViewer) ...[
          const SizedBox(height: 10),
          const _WaitingResponse(),
        ] else if (latest.canAccept) ...[
          const SizedBox(height: 12),
          AppButton(
            label: 'Aceitar proposta de ${formatRequestPrice(latest.totalCents)}',
            onPressed: acting ? null : () => onAccept(latest),
          ),
          if (negotiation.canPropose) ...[
            const SizedBox(height: 9),
            AppButton(
              label: 'Fazer contraproposta',
              variant: AppButtonVariant.outlined,
              onPressed: acting ? null : () => onPropose(latest),
            ),
          ],
        ] else if (latest.status == ServiceQuoteStatus.accepted) ...[
          const SizedBox(height: 10),
          const _AcceptedQuote(),
        ],
        if (negotiation.quotes.length > 1) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              'Histórico · ${negotiation.quotes.length} propostas',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            children: negotiation.quotes
                .skip(1)
                .map(
                  (quote) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _QuoteCard(quote: quote),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, this.highlighted = false});

  final ServiceQuote quote;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: highlighted ? AppColors.primarySoft : AppColors.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: highlighted ? AppColors.primary.withValues(alpha: .25) : AppColors.outline,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Proposta #${quote.revision} · ${quote.authorName}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _QuoteStatusBadge(status: quote.status),
          ],
        ),
        const SizedBox(height: 10),
        ...quote.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '${item.kind == ServiceQuoteItemKind.discount ? '− ' : ''}${formatRequestPrice(item.amountCents)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            Text(
              formatRequestPrice(quote.totalCents),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        if (quote.message.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            quote.message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
        if (quote.expiresAt case final expires?) ...[
          const SizedBox(height: 7),
          Text(
            'Válida até ${_shortDate(expires.toLocal())}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
        ],
      ],
    ),
  );
}

class _QuoteStatusBadge extends StatelessWidget {
  const _QuoteStatusBadge({required this.status});
  final ServiceQuoteStatus status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: status == ServiceQuoteStatus.accepted
          ? AppColors.primary.withValues(alpha: .13)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      switch (status) {
        ServiceQuoteStatus.proposed => 'Aguardando',
        ServiceQuoteStatus.accepted => 'Aceita',
        ServiceQuoteStatus.superseded => 'Substituída',
        ServiceQuoteStatus.withdrawn => 'Retirada',
      },
      style: fontStyle,
    ),
  );

  static const fontStyle = TextStyle(fontSize: 9, fontWeight: FontWeight.w900);
}

class _WaitingResponse extends StatelessWidget {
  const _WaitingResponse();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.hourglass_top_rounded, size: 17, color: AppColors.amber),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Aguardando a outra pessoa aceitar ou enviar uma contraproposta.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ),
    ],
  );
}

class _AcceptedQuote extends StatelessWidget {
  const _AcceptedQuote();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.verified_rounded, size: 18, color: AppColors.primary),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Valor acordado e registrado na solicitação.',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        ),
      ),
    ],
  );
}

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} às ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
