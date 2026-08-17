import 'dart:ui';

import 'package:flutter/material.dart';

import '../foundations/app_colors.dart';
import '../foundations/app_radius.dart';
import '../foundations/app_shadows.dart';

class AppProgressIndicator extends StatelessWidget {
  const AppProgressIndicator({
    this.size = 20,
    this.color = AppColors.primary,
    this.semanticsLabel = 'Carregando',
    super.key,
  });

  final double size;
  final Color color;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    liveRegion: true,
    child: SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: size <= 20 ? 2 : 2.6,
        color: color,
        backgroundColor: color.withValues(alpha: .14),
      ),
    ),
  );
}

class AppLinearProgressIndicator extends StatelessWidget {
  const AppLinearProgressIndicator({
    this.minHeight = 2,
    this.semanticsLabel = 'Carregando',
    super.key,
  });

  final double minHeight;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    liveRegion: true,
    child: LinearProgressIndicator(
      minHeight: minHeight,
      color: AppColors.primary,
      backgroundColor: AppColors.primarySoft,
    ),
  );
}

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({
    this.message = 'Carregando…',
    this.compact = false,
    super.key,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: message,
      liveRegion: true,
      container: true,
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: compact ? 42 : 52,
                  height: compact ? 42 : 52,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(
                    Icons.handyman_rounded,
                    size: compact ? 16 : 19,
                    color: AppColors.primaryDark,
                  ),
                ),
                AppProgressIndicator(
                  size: compact ? 42 : 52,
                  semanticsLabel: message,
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<T> runWithAppLoading<T>(
  BuildContext context, {
  required String message,
  required Future<T> Function() action,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final dialog = showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: AppColors.textPrimary.withValues(alpha: .22),
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: AppColors.surface.withValues(alpha: .72),
                ),
                boxShadow: AppShadows.soft,
              ),
              child: AppLoadingView(message: message, compact: true),
            ),
          ),
        ),
      ),
    ),
  );
  try {
    return await action();
  } finally {
    if (navigator.mounted && navigator.canPop()) navigator.pop();
    await dialog;
  }
}
