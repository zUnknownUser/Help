import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../domain/failures/service_request_failure.dart';
import '../providers/service_request_providers.dart';
import '../widgets/service_request_details_view.dart';

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
  String? _rescheduleCommandId;
  DateTime? _rescheduleIntent;

  @override
  void initState() {
    super.initState();
    _request = widget.initial;
    if (_request == null) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
          ),
  );

  Future<void> _load() async {
    setState(() => _loading = true);
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
  }

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
