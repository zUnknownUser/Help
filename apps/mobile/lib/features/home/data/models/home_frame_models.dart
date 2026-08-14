import '../../domain/entities/home_benefit.dart';
import '../../domain/entities/home_location.dart';
import 'json_reader.dart';

class HomeLocationModel {
  const HomeLocationModel(this.address, this.availabilityLabel);

  factory HomeLocationModel.fromJson(Map<String, dynamic> json) =>
      HomeLocationModel(
        JsonReader.string(json, 'address'),
        JsonReader.string(json, 'availability_label'),
      );

  final String address;
  final String availabilityLabel;

  HomeLocation toEntity() =>
      HomeLocation(address: address, availabilityLabel: availabilityLabel);
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
