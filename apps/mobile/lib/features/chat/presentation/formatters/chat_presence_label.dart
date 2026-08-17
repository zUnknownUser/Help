import '../../data/realtime/chat_realtime_coordinator.dart';

String chatPresenceLabel({
  required PresenceEvent presence,
  required RealtimeConnectionStatus connection,
  required bool typing,
  DateTime? now,
}) {
  if (connection == RealtimeConnectionStatus.connecting) return 'conectando…';
  if (connection == RealtimeConnectionStatus.disconnected) {
    return chatLastSeenLabel(
      online: false,
      lastSeenAt: presence.lastSeenAt,
      now: now,
    );
  }
  if (typing) return 'digitando…';
  return chatLastSeenLabel(
    online: presence.online,
    lastSeenAt: presence.lastSeenAt,
    now: now,
  );
}

String chatLastSeenLabel({
  required bool online,
  DateTime? lastSeenAt,
  DateTime? now,
}) {
  if (online) return 'online';
  if (lastSeenAt != null) {
    return _lastSeenLabel(lastSeenAt, now ?? DateTime.now());
  }
  return 'offline';
}

String _lastSeenLabel(DateTime value, DateTime now) {
  final local = value.toLocal();
  final date = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (date == today) return 'visto por último hoje às $time';
  if (date == today.subtract(const Duration(days: 1))) {
    return 'visto por último ontem às $time';
  }
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return 'visto por último em $day/$month/${local.year} às $time';
}
