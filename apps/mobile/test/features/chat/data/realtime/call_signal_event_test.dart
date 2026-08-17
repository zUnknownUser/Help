import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/chat/data/realtime/chat_event_types.dart';
import 'package:help/features/calls/domain/entities/call_signal.dart';

void main() {
  test('serializes only client-owned call signaling fields', () {
    const signal = CallSignal(
      type: ChatEventTypes.callOffer,
      callId: 'call-id',
      conversationId: 'conversation-id',
      fromUserId: 'forged-user',
      sdp: 'offer-sdp',
      sdpType: 'offer',
    );

    expect(signal.toWire(), {
      'call_id': 'call-id',
      'conversation_id': 'conversation-id',
      'sdp': 'offer-sdp',
      'sdp_type': 'offer',
    });
  });

  test('maps server-owned caller identity', () {
    final signal = CallSignal.fromWire(ChatEventTypes.callInvite, {
      'call_id': 'call-id',
      'conversation_id': 'conversation-id',
      'from_user_id': 'authenticated-user',
      'media_type': 'video',
    });

    expect(signal.fromUserId, 'authenticated-user');
    expect(signal.mediaType, 'video');
  });
}
