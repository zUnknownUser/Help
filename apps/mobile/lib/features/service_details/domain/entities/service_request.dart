class ServiceRequestDraft {
  const ServiceRequestDraft({
    required this.clientRequestId,
    required this.scheduledFor,
    required this.note,
  });

  final String clientRequestId;
  final DateTime scheduledFor;
  final String note;
}

class ServiceRequestReceipt {
  const ServiceRequestReceipt({
    required this.id,
    required this.clientRequestId,
    required this.serviceId,
    required this.serviceTitle,
    required this.providerName,
    required this.status,
    required this.scheduledFor,
    required this.quotedPriceCents,
    required this.address,
  });

  final String id;
  final String clientRequestId;
  final String serviceId;
  final String serviceTitle;
  final String providerName;
  final String status;
  final DateTime scheduledFor;
  final int quotedPriceCents;
  final String address;
}
