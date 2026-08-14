import '../../domain/entities/home_content.dart';
import 'home_frame_models.dart';
import 'json_reader.dart';
import 'promotion_model.dart';
import 'service_category_model.dart';
import 'service_offer_model.dart';

class HomeContentModel {
  const HomeContentModel({
    required this.location,
    required this.searchPlaceholder,
    required this.promotions,
    required this.categories,
    required this.recommendedServices,
    required this.benefits,
  });

  const HomeContentModel.empty()
    : location = const HomeLocationModel('', ''),
      searchPlaceholder = '',
      promotions = const [],
      categories = const [],
      recommendedServices = const [],
      benefits = const [];

  factory HomeContentModel.fromJson(Map<String, dynamic> json) =>
      HomeContentModel(
        location: HomeLocationModel.fromJson(
          JsonReader.map(json['location'], 'location'),
        ),
        searchPlaceholder: JsonReader.string(json, 'search_placeholder'),
        promotions: JsonReader.maps(
          json['promotions'],
          'promotions',
        ).map(PromotionModel.fromJson).toList(growable: false),
        categories: JsonReader.maps(
          json['categories'],
          'categories',
        ).map(ServiceCategoryModel.fromJson).toList(growable: false),
        recommendedServices: JsonReader.maps(
          json['recommended_services'],
          'recommended_services',
        ).map(ServiceOfferModel.fromJson).toList(growable: false),
        benefits: JsonReader.maps(
          json['benefits'],
          'benefits',
        ).map(HomeBenefitModel.fromJson).toList(growable: false),
      );

  final HomeLocationModel location;
  final String searchPlaceholder;
  final List<PromotionModel> promotions;
  final List<ServiceCategoryModel> categories;
  final List<ServiceOfferModel> recommendedServices;
  final List<HomeBenefitModel> benefits;

  HomeContent toEntity() => HomeContent(
    location: location.toEntity(),
    searchPlaceholder: searchPlaceholder,
    promotions: promotions
        .map((value) => value.toEntity())
        .toList(growable: false),
    categories: categories
        .map((value) => value.toEntity())
        .toList(growable: false),
    recommendedServices: recommendedServices
        .map((value) => value.toEntity())
        .toList(growable: false),
    benefits: benefits.map((value) => value.toEntity()).toList(growable: false),
  );
}
