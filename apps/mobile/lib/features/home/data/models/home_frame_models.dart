import '../../domain/entities/home_benefit.dart';
import '../../domain/entities/home_location.dart';
import '../../domain/entities/home_notification.dart';
import 'json_reader.dart';

class HomeLocationModel {
  const HomeLocationModel(
    this.address,
    this.availabilityLabel,
    this.latitude,
    this.longitude,
  );

  factory HomeLocationModel.fromJson(Map<String, dynamic> json) =>
      HomeLocationModel(
        JsonReader.string(json, 'address'),
        JsonReader.string(json, 'availability_label'),
        JsonReader.optionalDecimal(json, 'latitude'),
        JsonReader.optionalDecimal(json, 'longitude'),
      );

  final String address;
  final String availabilityLabel;
  final double? latitude;
  final double? longitude;

  HomeLocation toEntity() => HomeLocation(
    address: address,
    availabilityLabel: availabilityLabel,
    latitude: latitude,
    longitude: longitude,
  );
}

class HomeBenefitModel {
  const HomeBenefitModel(this.id, this.label, this.iconKey);

  factory HomeBenefitModel.fromJson(Map<String, dynamic> json) =>
      HomeBenefitModel(
        JsonReader.string(json, 'id'),
        JsonReader.string(json, 'label'),
        JsonReader.string(json, 'icon_key'),
      );

  final String id;
  final String label;
  final String iconKey;

  HomeBenefit toEntity() => HomeBenefit(id: id, label: label, iconKey: iconKey);
}

class HomeNotificationModel {
  const HomeNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  factory HomeNotificationModel.fromJson(Map<String, dynamic> json) =>
      HomeNotificationModel(
        id: JsonReader.string(json, 'id'),
        title: JsonReader.string(json, 'title'),
        body: JsonReader.string(json, 'body'),
        kind: JsonReader.optionalString(json, 'kind') ?? '',
        data: _notificationData(json['data']),
        read: JsonReader.boolean(json, 'read'),
        createdAt: DateTime.parse(JsonReader.string(json, 'created_at')),
      );

  final String id;
  final String title;
  final String body;
  final String kind;
  final Map<String, String> data;
  final bool read;
  final DateTime createdAt;

  HomeNotification toEntity() => HomeNotification(
    id: id,
    title: title,
    body: body,
    kind: kind,
    data: data,
    read: read,
    createdAt: createdAt,
  );
}

Map<String, String> _notificationData(Object? value) {
  if (value == null) return const {};
  final map = JsonReader.map(value, 'data');
  return map.map((key, value) {
    if (value is! String) {
      throw const FormatException('notification data must contain strings');
    }
    return MapEntry(key, value);
  });
}
