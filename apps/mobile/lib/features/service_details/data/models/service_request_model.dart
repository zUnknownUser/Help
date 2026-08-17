import '../../../home/data/models/json_reader.dart';
import '../../domain/entities/service_request.dart';

class ServiceRequestModel {
  const ServiceRequestModel(this.entity);

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    final address = JsonReader.map(json['address'], 'address');
    return ServiceRequestModel(
      ServiceRequestReceipt(
        id: JsonReader.string(json, 'id'),
        clientRequestId: JsonReader.string(json, 'client_request_id'),
        serviceId: JsonReader.string(json, 'service_id'),
        serviceTitle: JsonReader.string(json, 'service_title'),
        providerName: JsonReader.string(json, 'provider_name'),
        status: JsonReader.string(json, 'status'),
        scheduledFor: DateTime.parse(JsonReader.string(json, 'scheduled_for')),
        quotedPriceCents: JsonReader.integer(json, 'quoted_price_cents'),
        address: JsonReader.string(address, 'formatted_address'),
      ),
    );
  }

  final ServiceRequestReceipt entity;
}
