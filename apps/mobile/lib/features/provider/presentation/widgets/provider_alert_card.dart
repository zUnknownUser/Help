import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/provider_workspace.dart';

class ProviderAlertCard extends StatelessWidget {
  const ProviderAlertCard({
    required this.alert,
    required this.onTap,
    super.key,
  });

  final ProviderAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _background,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: _foreground, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: TextStyle(
                      color: _foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    alert.message,
                    style: TextStyle(color: _foreground, height: 1.35),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: _foreground),
          ],
        ),
      ),
    ),
  );

  bool get _warning => alert.kind == 'availability';
  Color get _background =>
      _warning ? const Color(0xFFFFF7E8) : AppColors.primarySoft;
  Color get _foreground =>
      _warning ? const Color(0xFF805300) : AppColors.primaryDark;
  IconData get _icon => switch (alert.kind) {
    'location' => Icons.location_on_outlined,
    'service' => Icons.add_business_outlined,
    'publication' => Icons.visibility_off_outlined,
    _ => Icons.pause_circle_outline_rounded,
  };
}
