import 'service_request_item.dart';

const maximumServiceRequestAttachments = 8;
const maximumServiceQuoteItems = 20;

enum ServiceQuoteItemKind {
  labor,
  material,
  addon,
  discount;

  static ServiceQuoteItemKind parse(String value) => switch (value) {
    'labor' => labor,
    'material' => material,
    'addon' => addon,
    'discount' => discount,
    _ => throw FormatException('Unknown quote item kind: $value'),
  };
}

enum ServiceQuoteStatus {
  proposed,
  accepted,
  superseded,
  withdrawn;

  static ServiceQuoteStatus parse(String value) => switch (value) {
    'proposed' => proposed,
    'accepted' => accepted,
    'superseded' => superseded,
    'withdrawn' => withdrawn,
    _ => throw FormatException('Unknown quote status: $value'),
  };
}

class ServiceQuoteItemDraft {
  const ServiceQuoteItemDraft({
    required this.kind,
    required this.description,
    required this.amountCents,
  });

  final ServiceQuoteItemKind kind;
  final String description;
  final int amountCents;
}

class ServiceQuoteItem {
  const ServiceQuoteItem({
    required this.id,
    required this.kind,
    required this.description,
    required this.amountCents,
    required this.position,
  });

  final String id;
  final ServiceQuoteItemKind kind;
  final String description;
  final int amountCents;
  final int position;
}

class ServiceQuoteDraft {
  const ServiceQuoteDraft({
    required this.items,
    this.message = '',
    this.expiresAt,
  });

  final List<ServiceQuoteItemDraft> items;
  final String message;
  final DateTime? expiresAt;

  int get totalCents => items.fold(0, (total, item) {
    if (item.kind == ServiceQuoteItemKind.discount) {
      return total - item.amountCents;
    }
    return total + item.amountCents;
  });
}

class ServiceQuote {
  const ServiceQuote({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.revision,
    required this.status,
    required this.currency,
    required this.totalCents,
    required this.message,
    required this.items,
    required this.createdAt,
    required this.canAccept,
    this.expiresAt,
    this.acceptedAt,
  });

  final String id;
  final String authorName;
  final RequestViewerRole authorRole;
  final int revision;
  final ServiceQuoteStatus status;
  final String currency;
  final int totalCents;
  final String message;
  final List<ServiceQuoteItem> items;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final bool canAccept;

  bool get isPending => status == ServiceQuoteStatus.proposed;
}

class ServiceRequestAttachment {
  const ServiceRequestAttachment({
    required this.id,
    required this.uploaderName,
    required this.uploaderRole,
    required this.caption,
    required this.contentType,
    required this.byteSize,
    required this.url,
    required this.createdAt,
    required this.canDelete,
  });

  final String id;
  final String uploaderName;
  final RequestViewerRole uploaderRole;
  final String caption;
  final String contentType;
  final int byteSize;
  final String url;
  final DateTime createdAt;
  final bool canDelete;
}

class ServiceRequestNegotiation {
  const ServiceRequestNegotiation({
    required this.attachments,
    required this.quotes,
    required this.canAddAttachment,
    required this.canPropose,
  });

  final List<ServiceRequestAttachment> attachments;
  final List<ServiceQuote> quotes;
  final bool canAddAttachment;
  final bool canPropose;

  ServiceQuote? get latestQuote => quotes.isEmpty ? null : quotes.first;
}

class ServiceRequestNegotiationUpdate {
  const ServiceRequestNegotiationUpdate({
    required this.request,
    required this.negotiation,
  });

  final ServiceRequestItem request;
  final ServiceRequestNegotiation negotiation;
}
