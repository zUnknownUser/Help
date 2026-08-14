import '../../domain/entities/promotion.dart';
import 'json_reader.dart';

class PromotionModel {
  const PromotionModel({
    required this.id,
    required this.eyebrow,
    required this.title,
    required this.features,
    required this.actions,
    this.imageUrl,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) => PromotionModel(
    id: JsonReader.string(json, 'id'),
    eyebrow: JsonReader.string(json, 'eyebrow'),
    title: JsonReader.string(json, 'title'),
    imageUrl: JsonReader.optionalString(json, 'image_url'),
    features: JsonReader.maps(
      json['features'],
      'features',
    ).map(PromotionFeatureModel.fromJson).toList(growable: false),
    actions: JsonReader.maps(
      json['actions'],
      'actions',
    ).map(PromotionActionModel.fromJson).toList(growable: false),
  );

  final String id;
  final String eyebrow;
  final String title;
  final String? imageUrl;
  final List<PromotionFeatureModel> features;
  final List<PromotionActionModel> actions;

  Promotion toEntity() => Promotion(
    id: id,
    eyebrow: eyebrow,
    title: title,
    imageUrl: imageUrl,
    features: features.map((value) => value.toEntity()).toList(growable: false),
    actions: actions.map((value) => value.toEntity()).toList(growable: false),
  );
}

class PromotionFeatureModel {
  const PromotionFeatureModel(this.iconKey, this.label);

  factory PromotionFeatureModel.fromJson(Map<String, dynamic> json) =>
      PromotionFeatureModel(
        JsonReader.string(json, 'icon_key'),
        JsonReader.string(json, 'label'),
      );

  final String iconKey;
  final String label;

  PromotionFeature toEntity() =>
      PromotionFeature(iconKey: iconKey, label: label);
}

class PromotionActionModel {
  const PromotionActionModel(
    this.id,
    this.label,
    this.iconKey,
    this.style,
    this.type,
    this.target,
  );

  factory PromotionActionModel.fromJson(Map<String, dynamic> json) =>
      PromotionActionModel(
        JsonReader.string(json, 'id'),
        JsonReader.string(json, 'label'),
        JsonReader.string(json, 'icon_key'),
        _parseStyle(JsonReader.string(json, 'style')),
        _parseType(JsonReader.string(json, 'type')),
        JsonReader.optionalString(json, 'target'),
      );

  final String id;
  final String label;
  final String iconKey;
  final PromotionActionStyle style;
  final PromotionActionType type;
  final String? target;

  PromotionAction toEntity() => PromotionAction(
    id: id,
    label: label,
    iconKey: iconKey,
    style: style,
    type: type,
    target: target,
  );

  static PromotionActionStyle _parseStyle(String value) => switch (value) {
    'primary' => PromotionActionStyle.primary,
    'secondary' => PromotionActionStyle.secondary,
    _ => throw FormatException('unknown promotion action style: $value'),
  };

  static PromotionActionType _parseType(String value) => switch (value) {
    'category' => PromotionActionType.category,
    'all_services' => PromotionActionType.allServices,
    _ => throw FormatException('unknown promotion action type: $value'),
  };
}
