import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/failures/home_failure.dart';
import 'home_nav_bar.dart';

class HomeErrorView extends StatelessWidget {
  const HomeErrorView({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  final HomeFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('home_error'),
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Não foi possível carregar os serviços',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    failure.type == HomeFailureType.network
                        ? 'Verifique sua conexão e tente novamente.'
                        : 'Tente novamente em alguns instantes.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  AppButton(label: 'Tentar novamente', onPressed: onRetry),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const HomeNavBar(),
    );
  }
}
