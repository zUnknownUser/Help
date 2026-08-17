import 'package:flutter/material.dart';

import '../foundations/app_colors.dart';
import '../foundations/app_radius.dart';
import 'app_loading.dart';

enum AppButtonVariant { primary, outlined, disabled }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.trailing,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final foreground = switch (variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.outlined => AppColors.textPrimary,
      AppButtonVariant.disabled => AppColors.textSecondary,
    };
    final background = switch (variant) {
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.outlined => AppColors.surface,
      AppButtonVariant.disabled => AppColors.disabledSurface,
    };

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: foreground,
          backgroundColor: background,
          disabledForegroundColor: variant == AppButtonVariant.disabled
              ? AppColors.textSecondary
              : foreground.withValues(alpha: .7),
          disabledBackgroundColor: variant == AppButtonVariant.disabled
              ? AppColors.disabledSurface
              : background.withValues(alpha: .7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: variant == AppButtonVariant.outlined
                ? const BorderSide(color: AppColors.outline)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? AppProgressIndicator(
                size: 20,
                color: foreground,
                semanticsLabel: '$label em andamento',
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading case final widget?) ...[
                    widget,
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing case final widget?) ...[
                    const SizedBox(width: 10),
                    widget,
                  ],
                ],
              ),
      ),
    );
  }
}
