import '../../../home/data/models/json_reader.dart';
import '../../domain/entities/service_request_item.dart';

class ServiceRequestItemModel {
  const ServiceRequestItemModel(this.entity);

  factory ServiceRequestItemModel.fromJson(Map<String, dynamic> json) {
    final address = JsonReader.map(json['address'], 'address');
    return ServiceRequestItemModel(
      ServiceRequestItem(
        id: JsonReader.string(json, 'id'),
        clientRequestId: JsonReader.string(json, 'client_request_id'),
        serviceId: JsonReader.string(json, 'service_id'),
        serviceTitle: JsonReader.string(json, 'service_title'),
        providerUserId:
            JsonReader.optionalString(json, 'provider_user_id') ?? '',
        providerName: JsonReader.string(json, 'provider_name'),
        customerName: JsonReader.optionalString(json, 'customer_name') ?? '',
        customerUserId:
            JsonReader.optionalString(json, 'customer_user_id') ?? '',
        viewerRole: RequestViewerRole.parse(
          JsonReader.string(json, 'viewer_role'),
        ),
        status: ServiceRequestStatus.parse(JsonReader.string(json, 'status')),
        statusReason: JsonReader.optionalString(json, 'status_reason') ?? '',
        version: JsonReader.integer(json, 'version'),
        availableActions: JsonReader.strings(
          json['available_actions'],
          'available_actions',
        ).map(ServiceRequestStatus.parse).toSet(),
        note: JsonReader.string(json, 'note'),
        scheduledFor: DateTime.parse(JsonReader.string(json, 'scheduled_for')),
        quotedPriceCents: JsonReader.integer(json, 'quoted_price_cents'),
        addressLabel: JsonReader.string(address, 'label'),
        address: JsonReader.string(address, 'formatted_address'),
        createdAt: DateTime.parse(JsonReader.string(json, 'created_at')),
        updatedAt: DateTime.parse(JsonReader.string(json, 'updated_at')),
      ),
    );
  }

  final ServiceRequestItem entity;
}
