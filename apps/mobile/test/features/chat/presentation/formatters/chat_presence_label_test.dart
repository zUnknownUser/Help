import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/chat/data/realtime/chat_realtime_coordinator.dart';
import 'package:help/features/chat/presentation/formatters/chat_presence_label.dart';

void main() {
  final now = DateTime(2026, 8, 16, 14);

  test('prioritizes typing and online states', () {
    const presence = PresenceEvent(userId: 'peer', online: true);
    expect(
      chatPresenceLabel(
        presence: presence,
        connection: RealtimeConnectionStatus.connected,
        typing: true,
        now: now,
      ),
      'digitando…',
    );
    expect(
      chatPresenceLabel(
        presence: presence,
        connection: RealtimeConnectionStatus.connected,
        typing: false,
        now: now,
      ),
      'online',
    );
  });

  test('formats last seen relative to the local day', () {
    final presence = PresenceEvent(
      userId: 'peer',
      online: false,
      lastSeenAt: DateTime(2026, 8, 15, 22, 7),
    );
    expect(
      chatPresenceLabel(
        presence: presence,
        connection: RealtimeConnectionStatus.connected,
        typing: false,
        now: now,
      ),
      'visto por último ontem às 22:07',
    );
  });

  test('does not show stale online state while realtime reconnects', () {
    expect(
      chatPresenceLabel(
        presence: const PresenceEvent(userId: 'peer', online: true),
        connection: RealtimeConnectionStatus.connecting,
        typing: false,
        now: now,
      ),
      'conectando…',
    );
  });

  test('disconnected session does not stay indefinitely connecting', () {
    expect(
      chatPresenceLabel(
        presence: const PresenceEvent(userId: 'peer', online: true),
        connection: RealtimeConnectionStatus.disconnected,
        typing: false,
        now: now,
      ),
      'offline',
    );
  });
}
