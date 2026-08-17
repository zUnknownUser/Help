abstract final class ChatEventTypes {
  static const sessionReady = 'session.ready';
  static const messageSend = 'message.send';
  static const messageAck = 'message.ack';
  static const messageNew = 'message.new';
  static const messageError = 'message.error';
  static const messageDelivered = 'message.delivered';
  static const messageRead = 'message.read';
  static const messageEdit = 'message.edit';
  static const messageDelete = 'message.delete';
  static const messageUpdated = 'message.updated';
  static const messageDeleted = 'message.deleted';
  static const mutationAck = 'message.mutation.ack';
  static const mutationError = 'message.mutation.error';
  static const typingStart = 'typing.start';
  static const typingStop = 'typing.stop';
  static const presenceChanged = 'presence.changed';
  static const conversationUpdated = 'conversation.updated';
  static const callInvite = 'call.invite';
  static const callRinging = 'call.ringing';
  static const callAccept = 'call.accept';
  static const callReject = 'call.reject';
  static const callOffer = 'call.offer';
  static const callAnswer = 'call.answer';
  static const callIce = 'call.ice';
  static const callHangup = 'call.hangup';
  static const callBusy = 'call.busy';
  static const callError = 'call.error';

  static const callEvents = <String>{
    callInvite,
    callRinging,
    callAccept,
    callReject,
    callOffer,
    callAnswer,
    callIce,
    callHangup,
    callBusy,
    callError,
  };
}
