import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/calls/application/call_session_controller.dart';
import 'package:help/features/calls/data/call_remote_api.dart';
import 'package:help/features/calls/domain/entities/call_session.dart';
import 'package:help/features/calls/domain/entities/call_signal.dart';
import 'package:help/features/calls/domain/repositories/call_signaling_gateway.dart';
import 'package:help/features/chat/data/realtime/chat_event_types.dart';
import 'package:http/testing.dart';

void main() {
  test(
    'routes an incoming invite and rejects a second concurrent call',
    () async {
      final signaling = _SignalingFake();
      final controller = CallSessionController(
        signaling,
        CallRemoteApi(MockClient((_) async => throw UnimplementedError()), ''),
      );
      addTearDown(controller.dispose);

      signaling.emit(
        const CallSignal(
          type: ChatEventTypes.callInvite,
          callId: 'call-1',
          conversationId: 'conversation-1',
          fromUserId: 'user-1',
          mediaType: 'audio',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.current?.phase, CallPhase.incoming);
      expect(controller.current?.peerUserId, 'user-1');
      expect(signaling.sent.single.type, ChatEventTypes.callRinging);

      signaling.emit(
        const CallSignal(
          type: ChatEventTypes.callInvite,
          callId: 'call-2',
          conversationId: 'conversation-2',
          fromUserId: 'user-2',
          mediaType: 'video',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(signaling.sent.last.type, ChatEventTypes.callBusy);
      expect(signaling.sent.last.callId, 'call-2');
      expect(controller.current?.id, 'call-1');
    },
  );

  test('decline emits a signal before ending the incoming session', () async {
    final signaling = _SignalingFake();
    final controller = CallSessionController(
      signaling,
      CallRemoteApi(MockClient((_) async => throw UnimplementedError()), ''),
    );
    addTearDown(controller.dispose);
    signaling.emit(
      const CallSignal(
        type: ChatEventTypes.callInvite,
        callId: 'call-1',
        conversationId: 'conversation-1',
        fromUserId: 'user-1',
        mediaType: 'video',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    await controller.decline();

    expect(signaling.sent.map((event) => event.type), [
      ChatEventTypes.callRinging,
      ChatEventTypes.callReject,
    ]);
    expect(controller.current?.phase, CallPhase.ended);
  });
}

class _SignalingFake implements CallSignalingGateway {
  final _events = StreamController<CallSignal>.broadcast();
  final sent = <CallSignal>[];

  @override
  Stream<CallSignal> get callEvents => _events.stream;

  @override
  bool get isConnected => true;

  void emit(CallSignal signal) => _events.add(signal);

  @override
  void sendCallSignal(CallSignal signal) => sent.add(signal);
}
