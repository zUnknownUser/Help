import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/home_content.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_offer.dart';
import '../../domain/entities/catalog_query.dart';
import '../pages/location_page.dart';
import '../pages/notifications_page.dart';
import '../pages/service_discovery_page.dart';
import '../../../profile/presentation/pages/account_page.dart';
import '../../../main_navigation/presentation/main_tab.dart';
import '../../../service_details/presentation/pages/service_details_page.dart';
import '../../../help_now/presentation/pages/help_now_start_page.dart';
import '../../../help_now/presentation/pages/help_now_tracking_page.dart';
import '../../../help_now/presentation/providers/help_now_providers.dart';
import '../../../help_now/presentation/widgets/help_now_card.dart';
import '../../../help_now/domain/entities/help_now_request.dart';
import '../providers/home_providers.dart';
import 'benefits_strip.dart';
import 'carousel_dots.dart';
import 'category_grid.dart';
import 'home_header.dart';
import 'home_empty_state.dart';
import 'promo_banner.dart';
import 'service_section.dart';

class HomeContentView extends ConsumerWidget {
  const HomeContentView({required this.content, this.onTabSelected, super.key});

  final HomeContent content;
  final ValueChanged<MainTab>? onTabSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpNow = ref.watch(customerHelpNowControllerProvider).value;
    final hasDynamicContent =
        content.promotions.isNotEmpty ||
        content.categories.isNotEmpty ||
        content.recommendedServices.isNotEmpty ||
        content.benefits.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: HomeHeader(
                    location: content.location,
                    searchPlaceholder: content.searchPlaceholder,
                    unreadNotificationCount: content.unreadNotificationCount,
                    onLocationTap: () => _openLocation(context, ref),
                    onNotificationsTap: () => _openNotifications(context, ref),
                    onSearchTap: () => _openServices(
                      context,
                      content.recommendationsTitle,
                      CatalogQuery(location: content.location),
                    ),
                    onAccountTap: () => _openAccount(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
                  sliver: SliverToBoxAdapter(
                    child: HelpNowCard(
                      request: helpNow,
                      onTap: () => _openHelpNow(context, ref, helpNow),
                    ),
                  ),
                ),
                if (content.promotions.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: PromoBanner(
                        promotion: content.promotions.first,
                        onAction: (action) => _openPromotion(context, action),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: CarouselDots(count: content.promotions.length),
                  ),
                ],
                if (content.categories.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: CategoryGrid(
                        title: content.categoriesTitle,
                        categories: content.categories,
                        onCategoryTap: (category) =>
                            _openCategory(context, category),
                      ),
                    ),
                  ),
                if (content.recommendedServices.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ServiceSection(
                      title: content.recommendationsTitle,
                      offers: content.recommendedServices,
                      onOfferTap: (offer) => _openDetails(context, offer),
                    ),
                  ),
                if (content.benefits.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: BenefitsStrip(benefits: content.benefits),
                    ),
                  ),
                if (!hasDynamicContent)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: HomeEmptyState(
                      needsLocation: content.location.latitude == null,
                      onLocation: () => _openLocation(context, ref),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openHelpNow(
    BuildContext context,
    WidgetRef ref,
    HelpNowRequest? active,
  ) async {
    if (active?.active ?? false) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const HelpNowTrackingPage()),
      );
      return;
    }
    if (!content.location.hasCoordinates) {
      await _openLocation(context, ref);
      return;
    }
    if (content.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma categoria disponível agora.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HelpNowStartPage(
          categories: content.categories,
          location: content.location,
        ),
      ),
    );
  }

  void _openAccount(BuildContext context) {
    final select = onTabSelected;
    if (select != null) {
      select(MainTab.account);
      return;
    }
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const AccountPage()));
  }

  Future<void> _openLocation(BuildContext context, WidgetRef ref) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LocationPage(current: content.location),
      ),
    );
    if (changed == true) {
      await ref.read(homeControllerProvider.notifier).retry();
    }
  }

  Future<void> _openNotifications(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationsPage(notifications: content.notifications),
      ),
    );
    await ref.read(homeControllerProvider.notifier).retry();
  }

  void _openPromotion(BuildContext context, PromotionAction action) {
    _openServices(
      context,
      action.label,
      CatalogQuery(
        categoryId: action.type == PromotionActionType.category
            ? action.target ?? ''
            : '',
        location: content.location,
      ),
    );
  }

  void _openCategory(BuildContext context, ServiceCategory category) {
    _openServices(
      context,
      category.name.replaceAll('\n', ' '),
      CatalogQuery(categoryId: category.id, location: content.location),
    );
  }

  void _openServices(BuildContext context, String title, CatalogQuery query) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ServiceDiscoveryPage(
          title: title.isEmpty ? 'Serviços' : title,
          initialQuery: query,
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, ServiceOffer offer) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ServiceDetailsPage(serviceId: offer.id, preview: offer),
      ),
    );
  }
}
