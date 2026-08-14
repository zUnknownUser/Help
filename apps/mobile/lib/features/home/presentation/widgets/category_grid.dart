import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/service_category.dart';
import '../icons/home_icon_resolver.dart';
import 'section_title.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    required this.title,
    required this.categories,
    required this.onCategoryTap,
    super.key,
  });

  final String title;
  final List<ServiceCategory> categories;
  final ValueChanged<ServiceCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionTitle(title: title),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 9,
            childAspectRatio: .9,
          ),
          itemBuilder: (context, index) => _CategoryTile(
            category: categories[index],
            onTap: () => onCategoryTap(categories[index]),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final ServiceCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                HomeIconResolver.resolve(category.iconKey),
                color: AppColors.primary,
                size: 25,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 9.2,
              height: 1.12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
