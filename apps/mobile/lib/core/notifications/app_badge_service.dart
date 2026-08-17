import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

abstract interface class AppBadgeService {
  Future<void> update(int count);
}

class PlatformAppBadgeService implements AppBadgeService {
  const PlatformAppBadgeService();

  @override
  Future<void> update(int count) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await AppBadgePlus.updateBadge(count.clamp(0, 999));
    } catch (_) {
      // Some Android launchers intentionally do not expose badge updates.
    }
  }
}
