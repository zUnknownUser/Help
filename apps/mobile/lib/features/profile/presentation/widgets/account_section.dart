import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';

class AccountSection extends StatelessWidget {
  const AccountSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: _separated(children)),
      ),
    ],
  );

  List<Widget> _separated(List<Widget> values) {
    final result = <Widget>[];
    for (var index = 0; index < values.length; index++) {
      if (index > 0) {
        result.add(const Divider(height: 1, indent: 58));
      }
      result.add(values[index]);
    }
    return result;
  }
}

class AccountTile extends StatelessWidget {
  const AccountTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor = AppColors.primary,
    this.trailing,
    this.iconAsset,
    this.assetColor,
    this.assetPadding = 6,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? iconAsset;
  final Color? assetColor;
  final double assetPadding;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 61,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    leading: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: iconAsset == null
          ? Icon(icon, color: iconColor, size: 20)
          : Padding(
              padding: EdgeInsets.all(assetPadding),
              child: Image.asset(
                iconAsset!,
                fit: BoxFit.contain,
                color: assetColor,
                colorBlendMode: assetColor == null ? null : BlendMode.srcIn,
                filterQuality: FilterQuality.high,
              ),
            ),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5),
          ),
    trailing:
        trailing ??
        (onTap == null
            ? null
            : const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              )),
    onTap: onTap,
  );
}
