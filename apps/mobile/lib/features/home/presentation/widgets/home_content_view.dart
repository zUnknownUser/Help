import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/home_content.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/catalog_query.dart';
import '../pages/location_page.dart';
import '../pages/notifications_page.dart';
import '../pages/service_discovery_page.dart';
import '../../../profile/presentation/pages/account_page.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../providers/home_providers.dart';
import 'benefits_strip.dart';
import 'carousel_dots.dart';
import 'category_grid.dart';
import 'home_header.dart';
import 'home_empty_state.dart';
import 'home_nav_bar.dart';
import 'promo_banner.dart';
import 'service_section.dart';

class HomeContentView extends ConsumerWidget {
  const HomeContentView({required this.content, super.key});

  final HomeContent content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatUnread = ref.watch(unreadChatCountProvider).value ?? 0;
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
                    onAccountTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const AccountPage()),
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
      bottomNavigationBar: HomeNavBar(
        chatUnreadCount: chatUnread,
        onConversationsTap: () => Navigator.of(
          context,
        ).push<void>(MaterialPageRoute(builder: (_) => const ChatListPage())),
        onAccountTap: () => Navigator.of(
          context,
        ).push<void>(MaterialPageRoute(builder: (_) => const AccountPage())),
      ),
    );
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
}
