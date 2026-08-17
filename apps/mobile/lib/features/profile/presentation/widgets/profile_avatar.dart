import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../auth/data/providers/auth_data_providers.dart';

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    required this.url,
    required this.size,
    required this.fallback,
    super.key,
  });

  final String url;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url.isEmpty) return _frame(fallback);
    final token = ref.watch(firebaseAuthProvider).currentUser?.getIdToken();
    return FutureBuilder<String?>(
      future: token,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (value == null) return _frame(fallback);
        return ClipOval(
          child: Image.network(
            _absoluteUrl(url),
            width: size,
            height: size,
            fit: BoxFit.cover,
            headers: {'Authorization': 'Bearer $value'},
            errorBuilder: (_, _, _) => _frame(fallback),
          ),
        );
      },
    );
  }

  Widget _frame(Widget child) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primarySoft,
    ),
    child: child,
  );
}

String _absoluteUrl(String value) =>
    value.startsWith('http') ? value : '${AppConfig.apiBaseUrl}$value';
