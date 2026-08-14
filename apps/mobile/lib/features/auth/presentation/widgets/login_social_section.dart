import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../../../core/design_system/foundations/app_spacing.dart';

class LoginSocialSection extends StatelessWidget {
  const LoginSocialSection({
    required this.isLoading,
    required this.onGooglePressed,
    super.key,
  });

  final bool isLoading;
  final VoidCallback onGooglePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _LoginDivider(),
        const SizedBox(height: 20),
        AppButton(
          key: const Key('login_google_button'),
          label: 'Continuar com Google',
          variant: AppButtonVariant.outlined,
          leading: const _GoogleMark(),
          isLoading: isLoading,
          onPressed: isLoading ? null : onGooglePressed,
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppButton(
          key: Key('login_apple_button'),
          label: 'Continuar com Apple',
          variant: AppButtonVariant.disabled,
          leading: Icon(Icons.apple_rounded, size: 21),
          trailing: _ComingSoonBadge(),
          onPressed: null,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SecurityNote(),
      ],
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.outline)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou continue com',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Divider(color: AppColors.outline)),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        'Em breve',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.primary),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Seus dados são protegidos e usados somente para sua conta.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
