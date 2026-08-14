abstract final class ChatEventTypes {
  static const sessionReady = 'session.ready';
  static const messageSend = 'message.send';
  static const messageAck = 'message.ack';
  static const messageNew = 'message.new';
  static const messageError = 'message.error';
  static const messageDelivered = 'message.delivered';
  static const messageRead = 'message.read';
  static const typingStart = 'typing.start';
  static const typingStop = 'typing.stop';
  static const presenceChanged = 'presence.changed';
}
