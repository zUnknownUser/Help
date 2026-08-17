import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../chat/data/realtime/chat_event_types.dart';
import '../../chat/domain/entities/chat_conversation.dart';
import '../data/call_remote_api.dart';
import '../domain/entities/call_session.dart';
import '../domain/entities/call_signal.dart';
import '../domain/repositories/call_signaling_gateway.dart';

class CallSessionController {
  CallSessionController(this._signaling, this._remote) {
    _signalSubscription = _signaling.callEvents.listen(_handleSignal);
  }

  final CallSignalingGateway _signaling;
  final CallRemoteApi _remote;
  final _changes = StreamController<CallSession?>.broadcast();
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  late final StreamSubscription<CallSignal> _signalSubscription;
  final List<RTCIceCandidate> _pendingCandidates = [];
  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  CallSession? _state;
  Timer? _answerTimeout;
  Timer? _elapsedTimer;
  Timer? _disconnectTimer;
  bool _renderersInitialized = false;
  bool _remoteDescriptionSet = false;
  bool _disposingPeer = false;

  CallSession? get current => _state;
  Stream<CallSession?> get states async* {
    yield _state;
    yield* _changes.stream;
  }

  Future<void> startOutgoing(
    ChatConversation conversation,
    CallMediaType mediaType,
  ) async {
    if (_hasOngoingCall) throw StateError('call_already_active');
    if (!_signaling.isConnected) throw StateError('realtime_disconnected');
    final session = CallSession(
      id: const Uuid().v4(),
      conversationId: conversation.id,
      peerUserId: conversation.otherUserId,
      peerDisplayName: conversation.otherDisplayName,
      mediaType: mediaType,
      phase: CallPhase.calling,
      outgoing: true,
      speakerEnabled: mediaType == CallMediaType.video,
    );
    _emit(session);
    try {
      await _preparePeer(session);
      _send(ChatEventTypes.callInvite, mediaType: mediaType.name);
      _startAnswerTimeout();
      AppLogger.realtime('call_started', fields: _logFields(session));
    } catch (_) {
      await _finish(CallPhase.failed, failureCode: 'media_unavailable');
      rethrow;
    }
  }

  Future<void> accept() async {
    final session = _state;
    if (session == null || session.phase != CallPhase.incoming) return;
    try {
      await _preparePeer(session);
      _emit(session.copyWith(phase: CallPhase.connecting));
      _send(ChatEventTypes.callAccept);
      _startAnswerTimeout();
    } catch (_) {
      _sendBestEffort(ChatEventTypes.callReject);
      await _finish(CallPhase.failed, failureCode: 'media_unavailable');
    }
  }

  Future<void> decline() async {
    if (_state?.phase != CallPhase.incoming) return;
    _sendBestEffort(ChatEventTypes.callReject);
    await _finish(CallPhase.ended);
  }

  Future<void> hangup() async {
    if (!_hasOngoingCall) return;
    _sendBestEffort(ChatEventTypes.callHangup);
    await _finish(CallPhase.ended);
  }

  Future<void> toggleMuted() async {
    final session = _state;
    if (session == null || session.hasEnded) return;
    final muted = !session.muted;
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    _emit(session.copyWith(muted: muted));
  }

  Future<void> toggleCamera() async {
    final session = _state;
    if (session == null || !session.isVideo || session.hasEnded) return;
    final enabled = !session.cameraEnabled;
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
    _emit(session.copyWith(cameraEnabled: enabled));
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  Future<void> toggleSpeaker() async {
    final session = _state;
    if (session == null || session.hasEnded) return;
    final enabled = !session.speakerEnabled;
    await Helper.setSpeakerphoneOn(enabled);
    _emit(session.copyWith(speakerEnabled: enabled));
  }

  void setPeerDisplayName(String value) {
    final session = _state;
    if (session == null || value.trim().isEmpty) return;
    _emit(session.copyWith(peerDisplayName: value.trim()));
  }

  Future<void> _preparePeer(CallSession session) async {
    if (_peer != null) return;
    if (!_renderersInitialized) {
      await Future.wait([
        localRenderer.initialize(),
        remoteRenderer.initialize(),
      ]);
      _renderersInitialized = true;
    }
    final ice = await _remote.iceConfiguration();
    final peer = await createPeerConnection({
      'iceServers': ice.servers.map((server) => server.toWebRTC()).toList(),
      'sdpSemantics': 'unified-plan',
    });
    _peer = peer;
    peer.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.sdpMLineIndex == null) {
        return;
      }
      _send(
        ChatEventTypes.callIce,
        candidate: candidate.candidate,
        sdpMid: candidate.sdpMid ?? '',
        sdpMLineIndex: candidate.sdpMLineIndex,
      );
    };
    peer.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
    };
    peer.onConnectionState = _onPeerConnectionState;

    final video = session.mediaType == CallMediaType.video;
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 720},
              'height': {'ideal': 1280},
              'frameRate': {'ideal': 24, 'max': 30},
            }
          : false,
    });
    _localStream = stream;
    localRenderer.srcObject = stream;
    for (final track in stream.getTracks()) {
      await peer.addTrack(track, stream);
    }
    await Helper.setSpeakerphoneOn(session.speakerEnabled);
  }

  Future<void> _handleSignal(CallSignal signal) async {
    if (signal.type == ChatEventTypes.callInvite) {
      await _handleInvite(signal);
      return;
    }
    final session = _state;
    if (session == null || signal.callId != session.id) return;
    try {
      switch (signal.type) {
        case ChatEventTypes.callAccept:
          if (session.outgoing) {
            _emit(session.copyWith(phase: CallPhase.connecting));
            await _createOffer();
          }
        case ChatEventTypes.callOffer:
          await _receiveOffer(signal);
        case ChatEventTypes.callAnswer:
          await _receiveAnswer(signal);
        case ChatEventTypes.callIce:
          await _receiveCandidate(signal);
        case ChatEventTypes.callReject:
        case ChatEventTypes.callBusy:
          await _finish(CallPhase.ended);
        case ChatEventTypes.callHangup:
          await _finish(CallPhase.ended);
        case ChatEventTypes.callError:
          await _finish(
            CallPhase.failed,
            failureCode: signal.errorCode ?? 'call_unavailable',
          );
      }
    } catch (_) {
      await _finish(CallPhase.failed, failureCode: 'connection_failed');
    }
  }

  Future<void> _handleInvite(CallSignal signal) async {
    if (_hasOngoingCall) {
      _signaling.sendCallSignal(
        CallSignal(
          type: ChatEventTypes.callBusy,
          callId: signal.callId,
          conversationId: signal.conversationId,
        ),
      );
      return;
    }
    final media = signal.mediaType == 'video'
        ? CallMediaType.video
        : CallMediaType.audio;
    final session = CallSession(
      id: signal.callId,
      conversationId: signal.conversationId,
      peerUserId: signal.fromUserId,
      peerDisplayName: 'Chamada recebida',
      mediaType: media,
      phase: CallPhase.incoming,
      outgoing: false,
      speakerEnabled: media == CallMediaType.video,
    );
    _emit(session);
    _sendBestEffort(ChatEventTypes.callRinging);
    _startAnswerTimeout();
    AppLogger.realtime('call_incoming', fields: _logFields(session));
  }

  Future<void> _createOffer() async {
    final offer = await _peer!.createOffer();
    await _peer!.setLocalDescription(offer);
    _send(ChatEventTypes.callOffer, sdp: offer.sdp, sdpType: offer.type);
  }

  Future<void> _receiveOffer(CallSignal signal) async {
    if (_peer == null || signal.sdp == null) return;
    await _peer!.setRemoteDescription(
      RTCSessionDescription(signal.sdp, 'offer'),
    );
    _remoteDescriptionSet = true;
    await _drainCandidates();
    final answer = await _peer!.createAnswer();
    await _peer!.setLocalDescription(answer);
    _send(ChatEventTypes.callAnswer, sdp: answer.sdp, sdpType: answer.type);
  }

  Future<void> _receiveAnswer(CallSignal signal) async {
    if (_peer == null || signal.sdp == null) return;
    await _peer!.setRemoteDescription(
      RTCSessionDescription(signal.sdp, 'answer'),
    );
    _remoteDescriptionSet = true;
    await _drainCandidates();
  }

  Future<void> _receiveCandidate(CallSignal signal) async {
    if (signal.candidate == null || signal.sdpMLineIndex == null) return;
    final candidate = RTCIceCandidate(
      signal.candidate,
      signal.sdpMid,
      signal.sdpMLineIndex,
    );
    if (_peer == null || !_remoteDescriptionSet) {
      _pendingCandidates.add(candidate);
      return;
    }
    await _peer!.addCandidate(candidate);
  }

  Future<void> _drainCandidates() async {
    final peer = _peer;
    if (peer == null || !_remoteDescriptionSet) return;
    for (final candidate in _pendingCandidates) {
      await peer.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  void _onPeerConnectionState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _disconnectTimer?.cancel();
        _answerTimeout?.cancel();
        final session = _state;
        if (session != null && session.phase != CallPhase.active) {
          _emit(session.copyWith(phase: CallPhase.active));
          _startElapsedTimer();
        }
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 8), () {
          unawaited(_finish(CallPhase.failed, failureCode: 'connection_lost'));
        });
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        unawaited(_finish(CallPhase.failed, failureCode: 'connection_failed'));
      default:
        break;
    }
  }

  void _startAnswerTimeout() {
    _answerTimeout?.cancel();
    _answerTimeout = Timer(const Duration(seconds: 45), () {
      _sendBestEffort(ChatEventTypes.callHangup);
      unawaited(_finish(CallPhase.failed, failureCode: 'not_answered'));
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = _state;
      if (session?.phase == CallPhase.active) {
        _emit(
          session!.copyWith(
            elapsed: session.elapsed + const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _send(
    String type, {
    String? mediaType,
    String? sdp,
    String? sdpType,
    String? candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) {
    final session = _state;
    if (session == null) return;
    _signaling.sendCallSignal(
      CallSignal(
        type: type,
        callId: session.id,
        conversationId: session.conversationId,
        mediaType: mediaType,
        sdp: sdp,
        sdpType: sdpType,
        candidate: candidate,
        sdpMid: sdpMid,
        sdpMLineIndex: sdpMLineIndex,
      ),
    );
  }

  void _sendBestEffort(String type) {
    try {
      _send(type);
    } catch (_) {
      AppLogger.realtime(
        'call_signal_skipped',
        fields: {'event_type': type, 'call_id': _state?.id},
      );
    }
  }

  Future<void> _finish(CallPhase phase, {String? failureCode}) async {
    final session = _state;
    if (session == null || session.hasEnded || _disposingPeer) return;
    _emit(session.copyWith(phase: phase, failureCode: failureCode));
    await _disposePeer();
    AppLogger.realtime(
      'call_finished',
      fields: {..._logFields(session), 'failure_code': failureCode},
    );
  }

  Future<void> _disposePeer() async {
    if (_disposingPeer) return;
    _disposingPeer = true;
    _answerTimeout?.cancel();
    _elapsedTimer?.cancel();
    _disconnectTimer?.cancel();
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;
    final stream = _localStream;
    final peer = _peer;
    _localStream = null;
    _peer = null;
    for (final track in stream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await stream?.dispose();
    await peer?.close();
    await peer?.dispose();
    if (_renderersInitialized) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
    }
    _disposingPeer = false;
  }

  void _emit(CallSession? value) {
    _state = value;
    _changes.add(value);
  }

  bool get _hasOngoingCall => _state != null && !_state!.hasEnded;

  Map<String, Object?> _logFields(CallSession session) => {
    'call_id': session.id,
    'conversation_id': session.conversationId,
    'peer_user_id': session.peerUserId,
    'media_type': session.mediaType.name,
  };

  Future<void> dispose() async {
    await _signalSubscription.cancel();
    await _disposePeer();
    if (_renderersInitialized) {
      await localRenderer.dispose();
      await remoteRenderer.dispose();
    }
    await _changes.close();
  }
}
