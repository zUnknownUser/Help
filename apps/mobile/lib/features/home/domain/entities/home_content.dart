import 'home_benefit.dart';
import 'home_location.dart';
import 'promotion.dart';
import 'service_category.dart';
import 'service_offer.dart';

class HomeContent {
  const HomeContent({
    required this.location,
    required this.searchPlaceholder,
    required this.promotions,
    required this.categories,
    required this.recommendedServices,
    required this.benefits,
  });

  const HomeContent.empty()
    : location = const HomeLocation(address: '', availabilityLabel: ''),
      searchPlaceholder = '',
      promotions = const [],
      categories = const [],
      recommendedServices = const [],
      benefits = const [];

  final HomeLocation location;
  final String searchPlaceholder;
  final List<Promotion> promotions;
  final List<ServiceCategory> categories;
  final List<ServiceOffer> recommendedServices;
  final List<HomeBenefit> benefits;
}
