enum ServiceRequestStatus {
  pending,
  accepted,
  rejected,
  inProgress,
  completed,
  cancelled,
  noShow;

  String get wireValue => switch (this) {
    inProgress => 'in_progress',
    noShow => 'no_show',
    _ => name,
  };

  static ServiceRequestStatus parse(String value) => switch (value) {
    'pending' => pending,
    'accepted' => accepted,
    'rejected' => rejected,
    'in_progress' => inProgress,
    'completed' => completed,
    'cancelled' => cancelled,
    'no_show' => noShow,
    _ => throw FormatException('Unknown request status: $value'),
  };
}

enum RequestViewerRole {
  customer,
  provider;

  static RequestViewerRole parse(String value) => switch (value) {
    'customer' => customer,
    'provider' => provider,
    _ => throw FormatException('Unknown request viewer role: $value'),
  };
}

class ServiceRequestItem {
  const ServiceRequestItem({
    required this.id,
    required this.clientRequestId,
    required this.serviceId,
    required this.serviceTitle,
    required this.providerUserId,
    required this.providerName,
    required this.customerName,
    required this.customerUserId,
    required this.viewerRole,
    required this.status,
    required this.statusReason,
    required this.version,
    required this.availableActions,
    required this.note,
    required this.scheduledFor,
    required this.quotedPriceCents,
    required this.addressLabel,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String clientRequestId;
  final String serviceId;
  final String serviceTitle;
  final String providerUserId;
  final String providerName;
  final String customerName;
  final String customerUserId;
  final RequestViewerRole viewerRole;
  final ServiceRequestStatus status;
  final String statusReason;
  final int version;
  final Set<ServiceRequestStatus> availableActions;
  final String note;
  final DateTime scheduledFor;
  final int quotedPriceCents;
  final String addressLabel;
  final String address;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get counterpartName =>
      viewerRole == RequestViewerRole.customer ? providerName : customerName;

  ServiceRequestItem copyWith({
    ServiceRequestStatus? status,
    String? statusReason,
    int? version,
    Set<ServiceRequestStatus>? availableActions,
    DateTime? scheduledFor,
  }) => ServiceRequestItem(
    id: id,
    clientRequestId: clientRequestId,
    serviceId: serviceId,
    serviceTitle: serviceTitle,
    providerUserId: providerUserId,
    providerName: providerName,
    customerName: customerName,
    customerUserId: customerUserId,
    viewerRole: viewerRole,
    status: status ?? this.status,
    statusReason: statusReason ?? this.statusReason,
    version: version ?? this.version,
    availableActions: availableActions ?? this.availableActions,
    note: note,
    scheduledFor: scheduledFor ?? this.scheduledFor,
    quotedPriceCents: quotedPriceCents,
    addressLabel: addressLabel,
    address: address,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

class ServiceRequestPageData {
  const ServiceRequestPageData({required this.items, required this.nextCursor});

  final List<ServiceRequestItem> items;
  final String nextCursor;
}
