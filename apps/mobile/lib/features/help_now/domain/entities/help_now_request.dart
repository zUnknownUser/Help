enum HelpNowStatus { searching, assigned, noProvider, cancelled }

class HelpNowRequest {
  const HelpNowRequest({
    required this.id,
    required this.clientId,
    required this.categoryId,
    required this.categoryName,
    required this.note,
    required this.address,
    required this.status,
    required this.wave,
    required this.assignedProviderName,
    required this.serviceRequestId,
    required this.createdAt,
    required this.searchExpiresAt,
  });

  final String id;
  final String clientId;
  final String categoryId;
  final String categoryName;
  final String note;
  final String address;
  final HelpNowStatus status;
  final int wave;
  final String assignedProviderName;
  final String serviceRequestId;
  final DateTime createdAt;
  final DateTime searchExpiresAt;

  bool get active =>
      status == HelpNowStatus.searching || status == HelpNowStatus.assigned;
}
