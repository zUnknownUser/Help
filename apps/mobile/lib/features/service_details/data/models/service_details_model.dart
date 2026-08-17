import '../../../home/data/models/json_reader.dart';
import '../../../home/data/models/service_offer_model.dart';
import '../../domain/entities/service_details.dart';

class ServiceDetailsModel {
  const ServiceDetailsModel(this.entity);

  factory ServiceDetailsModel.fromJson(Map<String, dynamic> json) {
    final request = JsonReader.map(json['request'], 'request');
    final addressValue = request['address'];
    final provider = JsonReader.map(json['provider'], 'provider');
    return ServiceDetailsModel(
      ServiceDetails(
        offer: ServiceOfferModel.fromJson(json).toEntity(),
        description: JsonReader.string(json, 'description'),
        providerUserId: JsonReader.string(provider, 'user_id'),
        serviceArea: JsonReader.string(json, 'service_area'),
        canRequest: JsonReader.boolean(request, 'can_request'),
        requestBlockedReason: JsonReader.string(request, 'blocked_reason'),
        requestAddress: addressValue == null
            ? null
            : _address(JsonReader.map(addressValue, 'address')),
      ),
    );
  }

  final ServiceDetails entity;

  static ServiceRequestAddress _address(Map<String, dynamic> json) =>
      ServiceRequestAddress(
        label: JsonReader.string(json, 'label'),
        formattedAddress: JsonReader.string(json, 'formatted_address'),
        latitude: JsonReader.decimal(json, 'latitude'),
        longitude: JsonReader.decimal(json, 'longitude'),
      );
}
