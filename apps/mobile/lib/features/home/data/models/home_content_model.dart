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
    required this.categoriesTitle,
    required this.recommendationsTitle,
    required this.unreadNotificationCount,
    required this.notifications,
    required this.promotions,
    required this.categories,
    required this.recommendedServices,
    required this.benefits,
  });

  const HomeContentModel.empty()
    : location = const HomeLocationModel('', '', null, null),
      searchPlaceholder = '',
      categoriesTitle = '',
      recommendationsTitle = '',
      unreadNotificationCount = 0,
      notifications = const [],
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
        categoriesTitle: JsonReader.string(json, 'categories_title'),
        recommendationsTitle: JsonReader.string(json, 'recommendations_title'),
        unreadNotificationCount: JsonReader.integer(
          json,
          'unread_notification_count',
        ),
        notifications: JsonReader.maps(
          json['notifications'],
          'notifications',
        ).map(HomeNotificationModel.fromJson).toList(growable: false),
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
  final String categoriesTitle;
  final String recommendationsTitle;
  final int unreadNotificationCount;
  final List<HomeNotificationModel> notifications;
  final List<PromotionModel> promotions;
  final List<ServiceCategoryModel> categories;
  final List<ServiceOfferModel> recommendedServices;
  final List<HomeBenefitModel> benefits;

  HomeContent toEntity() => HomeContent(
    location: location.toEntity(),
    searchPlaceholder: searchPlaceholder,
    categoriesTitle: categoriesTitle,
    recommendationsTitle: recommendationsTitle,
    unreadNotificationCount: unreadNotificationCount,
    notifications: notifications
        .map((value) => value.toEntity())
        .toList(growable: false),
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
