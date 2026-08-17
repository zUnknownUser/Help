import '../entities/call_signal.dart';

abstract interface class CallSignalingGateway {
  Stream<CallSignal> get callEvents;
  bool get isConnected;
  void sendCallSignal(CallSignal signal);
}
