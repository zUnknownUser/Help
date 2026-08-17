import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/service_request.dart';
import '../../domain/failures/service_details_failure.dart';
import '../../domain/use_cases/create_service_request.dart';

class ServiceRequestFormController extends ChangeNotifier {
  ServiceRequestFormController({
    required this.serviceId,
    required this.create,
    DateTime Function()? now,
    String Function()? newClientId,
  }) : _now = now ?? DateTime.now,
       clientRequestId = (newClientId ?? const Uuid().v4)();

  final String serviceId;
  final String clientRequestId;
  final CreateServiceRequest create;
  final DateTime Function() _now;

  DateTime? _scheduledFor;
  bool _submitting = false;
  String? _error;
  bool _disposed = false;

  DateTime? get scheduledFor => _scheduledFor;
  bool get submitting => _submitting;
  String? get error => _error;

  void selectSchedule(DateTime value) {
    _scheduledFor = value;
    _error = null;
    _notify();
  }

  Future<ServiceRequestReceipt?> submit(String note) async {
    if (_submitting) return null;
    final scheduledFor = _scheduledFor;
    if (scheduledFor == null) {
      _error = 'Escolha um horário disponível.';
      _notify();
      return null;
    }
    if (scheduledFor.isBefore(_now().add(const Duration(minutes: 15)))) {
      _error = 'Escolha um horário com pelo menos 15 minutos de antecedência.';
      _notify();
      return null;
    }
    _submitting = true;
    _error = null;
    _notify();
    final result = await create(
      serviceId,
      ServiceRequestDraft(
        clientRequestId: clientRequestId,
        scheduledFor: scheduledFor,
        note: note,
      ),
    );
    return result.fold(
      onSuccess: (receipt) {
        _submitting = false;
        _notify();
        return receipt;
      },
      onFailure: (failure) {
        _submitting = false;
        _error = serviceRequestFailureMessage(failure);
        _notify();
        return null;
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

String serviceRequestFailureMessage(ServiceDetailsFailure failure) {
  if (failure.message case final message? when message.trim().isNotEmpty) {
    return message;
  }
  return switch (failure.type) {
    ServiceDetailsFailureType.addressRequired =>
      'Atualize o endereço do atendimento e tente novamente.',
    ServiceDetailsFailureType.forbidden =>
      'Esta conta não pode solicitar esse serviço.',
    ServiceDetailsFailureType.conflict =>
      'A tentativa entrou em conflito. Feche e abra o formulário novamente.',
    ServiceDetailsFailureType.invalid =>
      'Confira a data, o horário e a observação.',
    _ => 'Não foi possível enviar agora. Tente novamente sem fechar esta tela.',
  };
}
