import '../../domain/entities/service_category.dart';
import 'json_reader.dart';

class ServiceCategoryModel {
  const ServiceCategoryModel(this.id, this.name, this.iconKey);

  factory ServiceCategoryModel.fromJson(Map<String, dynamic> json) =>
      ServiceCategoryModel(
        JsonReader.string(json, 'id'),
        JsonReader.string(json, 'name'),
        JsonReader.string(json, 'icon_key'),
      );

  final String id;
  final String name;
  final String iconKey;

  ServiceCategory toEntity() =>
      ServiceCategory(id: id, name: name, iconKey: iconKey);
}
