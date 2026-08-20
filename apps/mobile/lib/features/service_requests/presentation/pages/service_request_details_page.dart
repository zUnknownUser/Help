import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../chat/data/providers/chat_data_providers.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../scheduling/data/scheduling_providers.dart';
import '../../../scheduling/presentation/controllers/slot_pager.dart';
import '../../../scheduling/presentation/widgets/available_slots_picker.dart';
import '../../domain/entities/service_request_item.dart';
import '../../domain/entities/service_request_negotiation.dart';
import '../../domain/failures/service_request_failure.dart';
import '../providers/service_request_providers.dart';
import '../widgets/service_request_details_view.dart';
import '../widgets/service_quote_sheet.dart';
import '../widgets/service_request_tile.dart';

class ServiceRequestDetailsPage extends ConsumerStatefulWidget {
  const ServiceRequestDetailsPage({
    required this.requestId,
    this.initial,
    super.key,
  });

  final String requestId;
  final ServiceRequestItem? initial;

  @override
  ConsumerState<ServiceRequestDetailsPage> createState() =>
      _ServiceRequestDetailsPageState();
}

class _ServiceRequestDetailsPageState
    extends ConsumerState<ServiceRequestDetailsPage> {
  final _commandIds = <ServiceRequestStatus, String>{};
  ServiceRequestItem? _request;
  bool _loading = false;
  bool _acting = false;
  bool _negotiationLoading = false;
  ServiceRequestNegotiation? _negotiation;
  String? _pendingQuoteCommandId;
  ServiceQuoteDraft? _pendingQuoteDraft;
  final _acceptCommandIds = <String, String>{};
  String? _rescheduleCommandId;
  DateTime? _rescheduleIntent;

  @override
  void initState() {
    super.initState();
    _request = widget.initial;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(serviceRequestRealtimeEventProvider, (_, next) {
      next.whenData((event) {
        if (event.data['request_id'] == widget.requestId) {
          unawaited(_loadNegotiation());
        }
      });
    });
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Detalhes da solicitação')),
      body: _loading && _request == null
          ? const AppLoadingView(message: 'Carregando solicitação…')
          : _request == null
          ? ServiceRequestDetailsError(onRetry: _load)
          : ServiceRequestDetailsView(
              request: _request!,
              acting: _acting,
              onAction: _transition,
              onChat: _openChat,
              onReschedule: _canReschedule(_request!) ? _reschedule : null,
              negotiation: _negotiation,
              negotiationLoading: _negotiationLoading,
              onNegotiationRetry: _loadNegotiation,
              onQuote: _openQuote,
              onAcceptQuote: _acceptQuote,
              onAddAttachment: _addAttachments,
              onDeleteAttachment: _deleteAttachment,
            ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = _request == null;
      _negotiationLoading = true;
    });
    final result = await ref
        .read(serviceRequestActionsProvider)
        .negotiation(widget.requestId);
    if (!mounted) return;
    result.fold(
      onSuccess: (value) => setState(() {
        _request = value.request;
        _negotiation = value.negotiation;
        _loading = false;
        _negotiationLoading = false;
      }),
      onFailure: (_) {
        setState(() => _negotiationLoading = false);
        if (_request == null) unawaited(_loadRequestOnly());
      },
    );
  }

  Future<void> _loadRequestOnly() async {
    final result = await ref
        .read(serviceRequestActionsProvider)
        .get(widget.requestId);
    if (!mounted) return;
    result.fold(
      onSuccess: (value) => setState(() {
        _request = value;
        _loading = false;
      }),
      onFailure: (_) => setState(() => _loading = false),
    );
  }

  Future<void> _loadNegotiation() async {
    if (_negotiationLoading) return;
    setState(() => _negotiationLoading = true);
    final result = await ref
        .read(serviceRequestActionsProvider)
        .negotiation(widget.requestId);
    if (!mounted) return;
    result.fold(
      onSuccess: _applyNegotiationUpdate,
      onFailure: (_) => setState(() => _negotiationLoading = false),
    );
  }

  Future<void> _transition(ServiceRequestStatus target) async {
    final current = _request;
    if (current == null || _acting) return;
    final reason = await _confirmTransition(target);
    if (reason == null || !mounted) return;
    final commandId = _commandIds.putIfAbsent(target, const Uuid().v4);
    _showOptimistic(current, target);
    final result = await ref
        .read(serviceRequestActionsProvider)
        .transition(
          request: current,
          commandId: commandId,
          target: target,
          reason: reason,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (confirmed) => _reconcile(target, confirmed),
      onFailure: (failure) {
        setState(() {
          _request = current;
          _acting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.message ??
                  'Não foi possível atualizar a solicitação. Tente novamente.',
            ),
          ),
        );
        if (failure.type == ServiceRequestFailureType.conflict) {
          _load();
        }
      },
    );
  }

  void _showOptimistic(
    ServiceRequestItem current,
    ServiceRequestStatus target,
  ) => setState(() {
    _acting = true;
    _request = current.copyWith(
      status: target,
      version: current.version + 1,
      availableActions: const {},
    );
  });

  void _reconcile(ServiceRequestStatus target, ServiceRequestItem confirmed) {
    _commandIds.remove(target);
    ref.read(serviceRequestsControllerProvider.notifier).reconcile(confirmed);
    setState(() {
      _request = confirmed;
      _acting = false;
    });
    unawaited(_loadNegotiation());
  }

  Future<void> _openQuote(ServiceQuote? previous) async {
    final request = _request;
    if (request == null || _acting) return;
    final draft = await showModalBottomSheet<ServiceQuoteDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      builder: (_) => ServiceQuoteSheet(
        currentPriceCents: request.quotedPriceCents,
        previous: previous,
        isCounterOffer: previous != null,
      ),
    );
    if (draft == null || !mounted) return;
    _pendingQuoteDraft = draft;
    _pendingQuoteCommandId = const Uuid().v4();
    await _submitQuote(draft, _pendingQuoteCommandId!);
  }

  Future<void> _submitQuote(
    ServiceQuoteDraft draft,
    String commandId,
  ) async {
    final request = _request;
    if (request == null || _acting) return;
    setState(() => _acting = true);
    final result = await ref
        .read(serviceRequestActionsProvider)
        .proposeQuote(request: request, commandId: commandId, draft: draft);
    if (!mounted) return;
    result.fold(
      onSuccess: (update) {
        _pendingQuoteCommandId = null;
        _pendingQuoteDraft = null;
        _applyNegotiationUpdate(update);
      },
      onFailure: (failure) {
        setState(() => _acting = false);
        final retryable = _isRetryable(failure);
        if (!retryable) {
          _pendingQuoteCommandId = null;
          _pendingQuoteDraft = null;
        }
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              failure.message ?? 'Não foi possível enviar a proposta.',
            ),
            action: retryable
                ? SnackBarAction(
                    label: 'Tentar novamente',
                    onPressed: () {
                      final pending = _pendingQuoteDraft;
                      final pendingId = _pendingQuoteCommandId;
                      if (pending != null && pendingId != null) {
                        unawaited(_submitQuote(pending, pendingId));
                      }
                    },
                  )
                : null,
          ),
        );
        if (failure.type == ServiceRequestFailureType.conflict) {
          unawaited(_load());
        }
      },
    );
  }

  Future<void> _acceptQuote(ServiceQuote quote) async {
    final request = _request;
    if (request == null || _acting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.verified_outlined, color: AppColors.primary),
        title: const Text('Aceitar esta proposta?'),
        content: Text(
          'O valor combinado será atualizado para ${formatRequestPrice(quote.totalCents)} e ficará registrado no atendimento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aceitar proposta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final commandId = _acceptCommandIds.putIfAbsent(
      quote.id,
      const Uuid().v4,
    );
    await _submitAcceptance(quote, commandId);
  }

  Future<void> _submitAcceptance(ServiceQuote quote, String commandId) async {
    final request = _request;
    if (request == null || _acting) return;
    setState(() => _acting = true);
    final result = await ref
        .read(serviceRequestActionsProvider)
        .acceptQuote(
          request: request,
          quoteId: quote.id,
          commandId: commandId,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (update) {
        _acceptCommandIds.remove(quote.id);
        _applyNegotiationUpdate(update);
      },
      onFailure: (failure) {
        setState(() => _acting = false);
        final retryable = _isRetryable(failure);
        if (!retryable) _acceptCommandIds.remove(quote.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.message ?? 'Não foi possível aceitar a proposta.',
            ),
            action: retryable
                ? SnackBarAction(
                    label: 'Tentar novamente',
                    onPressed: () => unawaited(
                      _submitAcceptance(quote, commandId),
                    ),
                  )
                : null,
          ),
        );
        if (failure.type == ServiceRequestFailureType.conflict) {
          unawaited(_load());
        }
      },
    );
  }

  Future<void> _addAttachments() async {
    final negotiation = _negotiation;
    if (negotiation == null || _acting) return;
    final remaining =
        maximumServiceRequestAttachments - negotiation.attachments.length;
    if (remaining <= 0) return;
    final images = await ImagePicker().pickMultiImage(
      imageQuality: 84,
      maxWidth: 1800,
    );
    if (images.isEmpty || !mounted) return;
    final selected = images.take(remaining).toList(growable: false);
    setState(() => _acting = true);
    var failures = 0;
    for (final image in selected) {
      final result = await ref
          .read(serviceRequestActionsProvider)
          .uploadAttachment(requestId: widget.requestId, filePath: image.path);
      result.fold(
        onSuccess: (_) {},
        onFailure: (_) => failures++,
      );
    }
    if (!mounted) return;
    setState(() => _acting = false);
    await _loadNegotiation();
    if (failures > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failures == 1
                ? 'Uma imagem não pôde ser enviada.'
                : '$failures imagens não puderam ser enviadas.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteAttachment(ServiceRequestAttachment attachment) async {
    if (_acting) return;
    setState(() => _acting = true);
    final result = await ref
        .read(serviceRequestActionsProvider)
        .deleteAttachment(
          requestId: widget.requestId,
          attachmentId: attachment.id,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        setState(() => _acting = false);
        ref.invalidate(serviceRequestAttachmentBytesProvider(attachment.id));
        unawaited(_loadNegotiation());
      },
      onFailure: (failure) {
        setState(() => _acting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.message ?? 'Não foi possível remover a imagem.',
            ),
          ),
        );
        if (failure.type == ServiceRequestFailureType.conflict) {
          unawaited(_load());
        }
      },
    );
  }

  void _applyNegotiationUpdate(ServiceRequestNegotiationUpdate update) {
    ref
        .read(serviceRequestsControllerProvider.notifier)
        .reconcile(update.request);
    setState(() {
      _request = update.request;
      _negotiation = update.negotiation;
      _acting = false;
      _loading = false;
      _negotiationLoading = false;
    });
  }

  bool _isRetryable(ServiceRequestFailure failure) =>
      failure.type == ServiceRequestFailureType.network ||
      failure.type == ServiceRequestFailureType.unavailable;

  Future<String?> _confirmTransition(ServiceRequestStatus target) async {
    final controller = TextEditingController();
    final needsReason =
        target == ServiceRequestStatus.rejected ||
        target == ServiceRequestStatus.cancelled;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          22,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              requestActionLabel(target),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              requestActionDescription(target),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (needsReason) ...[
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                ),
              ),
            ],
            const SizedBox(height: 18),
            AppButton(
              label: 'Confirmar',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    final value = confirmed == true ? controller.text.trim() : null;
    controller.dispose();
    return value;
  }

  Future<void> _openChat() async {
    final request = _request!;
    final userId = request.viewerRole == RequestViewerRole.customer
        ? request.providerUserId
        : request.customerUserId;
    if (userId.isEmpty) return;
    try {
      final conversation = await runWithAppLoading(
        context,
        message: 'Abrindo conversa…',
        action: () =>
            ref.read(chatRealtimeCoordinatorProvider).startDirect(userId),
      );
      if (mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ChatPage(conversation: conversation),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a conversa.')),
        );
      }
    }
  }

  bool _canReschedule(ServiceRequestItem request) =>
      request.viewerRole == RequestViewerRole.customer &&
      (request.status == ServiceRequestStatus.pending ||
          request.status == ServiceRequestStatus.accepted);

  Future<void> _reschedule() async {
    final current = _request;
    if (current == null || _acting) return;
    final pager = SlotPager(
      repository: ref.read(schedulingRepositoryProvider),
      serviceId: current.serviceId,
    )..load();
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      builder: (_) => AvailableSlotsPicker(pager: pager),
    );
    pager.dispose();
    if (selected == null || !mounted) return;
    if (_rescheduleIntent != selected) {
      _rescheduleIntent = selected;
      _rescheduleCommandId = const Uuid().v4();
    }
    final commandId = _rescheduleCommandId!;
    setState(() {
      _acting = true;
      _request = current.copyWith(
        scheduledFor: selected,
        status: ServiceRequestStatus.pending,
        version: current.version + 1,
        availableActions: const {},
      );
    });
    final result = await ref
        .read(serviceRequestActionsProvider)
        .reschedule(
          request: current,
          commandId: commandId,
          scheduledFor: selected,
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (confirmed) {
        _rescheduleCommandId = null;
        _rescheduleIntent = null;
        ref
            .read(serviceRequestsControllerProvider.notifier)
            .reconcile(confirmed);
        setState(() {
          _request = confirmed;
          _acting = false;
        });
        unawaited(_loadNegotiation());
      },
      onFailure: (failure) {
        setState(() {
          _request = current;
          _acting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.message ?? 'Não foi possível alterar o horário.',
            ),
          ),
        );
        if (failure.type == ServiceRequestFailureType.conflict) _load();
      },
    );
  }
}
