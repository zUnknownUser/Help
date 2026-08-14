import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/home_content.dart';
import 'benefits_strip.dart';
import 'carousel_dots.dart';
import 'category_grid.dart';
import 'home_header.dart';
import 'home_nav_bar.dart';
import 'promo_banner.dart';
import 'service_section.dart';

class HomeContentView extends StatelessWidget {
  const HomeContentView({required this.content, super.key});

  final HomeContent content;

  @override
  Widget build(BuildContext context) {
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
                  ),
                ),
                if (content.promotions.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: PromoBanner(promotion: content.promotions.first),
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
                      child: CategoryGrid(categories: content.categories),
                    ),
                  ),
                if (content.recommendedServices.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ServiceSection(offers: content.recommendedServices),
                  ),
                if (content.benefits.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: BenefitsStrip(benefits: content.benefits),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const HomeNavBar(),
    );
  }
}
