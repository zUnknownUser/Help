enum CallMediaType { audio, video }

enum CallPhase { incoming, calling, connecting, active, ended, failed }

class CallSession {
  const CallSession({
    required this.id,
    required this.conversationId,
    required this.peerUserId,
    required this.peerDisplayName,
    required this.mediaType,
    required this.phase,
    required this.outgoing,
    this.muted = false,
    this.cameraEnabled = true,
    this.speakerEnabled = false,
    this.elapsed = Duration.zero,
    this.failureCode,
  });

  final String id;
  final String conversationId;
  final String peerUserId;
  final String peerDisplayName;
  final CallMediaType mediaType;
  final CallPhase phase;
  final bool outgoing;
  final bool muted;
  final bool cameraEnabled;
  final bool speakerEnabled;
  final Duration elapsed;
  final String? failureCode;

  bool get hasEnded => phase == CallPhase.ended || phase == CallPhase.failed;
  bool get isVideo => mediaType == CallMediaType.video;

  CallSession copyWith({
    String? peerDisplayName,
    CallPhase? phase,
    bool? muted,
    bool? cameraEnabled,
    bool? speakerEnabled,
    Duration? elapsed,
    String? failureCode,
  }) => CallSession(
    id: id,
    conversationId: conversationId,
    peerUserId: peerUserId,
    peerDisplayName: peerDisplayName ?? this.peerDisplayName,
    mediaType: mediaType,
    phase: phase ?? this.phase,
    outgoing: outgoing,
    muted: muted ?? this.muted,
    cameraEnabled: cameraEnabled ?? this.cameraEnabled,
    speakerEnabled: speakerEnabled ?? this.speakerEnabled,
    elapsed: elapsed ?? this.elapsed,
    failureCode: failureCode ?? this.failureCode,
  );
}
