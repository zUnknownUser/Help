import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/profile_failure.dart';
import '../controllers/profile_controller.dart';
import '../providers/profile_providers.dart';
import 'profile_setup_page.dart';
import 'provider_home_page.dart';
import '../../../../core/session/session_lifecycle.dart';

class ProfileGate extends ConsumerWidget {
  const ProfileGate({required this.user, super.key});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currentProfileProvider);
    return state.when(
      data: (profile) => SessionLifecycle(
        userId: user.id,
        child: profile.activeRole == UserRole.provider
            ? ProviderHomePage(profile: profile)
            : const HomePage(),
      ),
      loading: () => const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) {
        final failure = error is ProfilePresentationException
            ? error.failure
            : const ProfileFailure(ProfileFailureType.unknown);
        if (failure.type == ProfileFailureType.notFound) {
          return ProfileSetupPage(initialDisplayName: user.displayName);
        }
        return _ProfileErrorPage(
          onRetry: ref.read(currentProfileProvider.notifier).retry,
        );
      },
    );
  }
}

class _ProfileErrorPage extends StatelessWidget {
  const _ProfileErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível carregar seu perfil.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 220,
                child: AppButton(label: 'Tentar novamente', onPressed: onRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
