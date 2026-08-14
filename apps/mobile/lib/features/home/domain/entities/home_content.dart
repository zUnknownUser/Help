import 'home_benefit.dart';
import 'home_location.dart';
import 'home_notification.dart';
import 'promotion.dart';
import 'service_category.dart';
import 'service_offer.dart';

class HomeContent {
  const HomeContent({
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

  const HomeContent.empty()
    : location = const HomeLocation(address: '', availabilityLabel: ''),
      searchPlaceholder = '',
      categoriesTitle = '',
      recommendationsTitle = '',
      unreadNotificationCount = 0,
      notifications = const [],
      promotions = const [],
      categories = const [],
      recommendedServices = const [],
      benefits = const [];

  final HomeLocation location;
  final String searchPlaceholder;
  final String categoriesTitle;
  final String recommendationsTitle;
  final int unreadNotificationCount;
  final List<HomeNotification> notifications;
  final List<Promotion> promotions;
  final List<ServiceCategory> categories;
  final List<ServiceOffer> recommendedServices;
  final List<HomeBenefit> benefits;
}
