import 'package:flutter/material.dart';

import 'core/design_system/components/app_brand.dart';
import 'core/design_system/foundations/app_colors.dart';
import 'core/design_system/theme/app_theme.dart';
import 'features/auth/presentation/pages/auth_gate.dart';

class HelpApp extends StatelessWidget {
  const HelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Help',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

class HelpStartupFailureApp extends StatelessWidget {
  const HelpStartupFailureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Help',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBrand(),
                  SizedBox(height: 24),
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 38,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Não foi possível iniciar o Help.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Verifique sua conexão e abra o aplicativo novamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
