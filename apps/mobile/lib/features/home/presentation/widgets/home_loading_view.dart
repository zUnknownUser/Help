import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';

class HomeLoadingView extends StatelessWidget {
  const HomeLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home_loading'),
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Skeleton(width: 220, height: 38),
              SizedBox(height: 14),
              _Skeleton(height: 43),
              SizedBox(height: 16),
              _Skeleton(height: 194, radius: 16),
              SizedBox(height: 18),
              _Skeleton(width: 150, height: 18),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Skeleton(height: 76)),
                  SizedBox(width: 9),
                  Expanded(child: _Skeleton(height: 76)),
                  SizedBox(width: 9),
                  Expanded(child: _Skeleton(height: 76)),
                  SizedBox(width: 9),
                  Expanded(child: _Skeleton(height: 76)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.width, required this.height, this.radius = 11});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.disabledSurface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
