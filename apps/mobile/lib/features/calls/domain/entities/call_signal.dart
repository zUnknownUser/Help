class CallSignal {
  const CallSignal({
    required this.type,
    required this.callId,
    required this.conversationId,
    this.fromUserId = '',
    this.mediaType,
    this.sdp,
    this.sdpType,
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
    this.errorCode,
  });

  final String type;
  final String callId;
  final String conversationId;
  final String fromUserId;
  final String? mediaType;
  final String? sdp;
  final String? sdpType;
  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  final String? errorCode;

  Map<String, Object?> toWire() => {
    'call_id': callId,
    'conversation_id': conversationId,
    if (mediaType != null) 'media_type': mediaType,
    if (sdp != null) 'sdp': sdp,
    if (sdpType != null) 'sdp_type': sdpType,
    if (candidate != null) 'candidate': candidate,
    if (sdpMid != null) 'sdp_mid': sdpMid,
    if (sdpMLineIndex != null) 'sdp_mline_index': sdpMLineIndex,
  };

  factory CallSignal.fromWire(String type, Map<String, dynamic> json) =>
      CallSignal(
        type: type,
        callId: json['call_id'] as String? ?? '',
        conversationId: json['conversation_id'] as String? ?? '',
        fromUserId: json['from_user_id'] as String? ?? '',
        mediaType: json['media_type'] as String?,
        sdp: json['sdp'] as String?,
        sdpType: json['sdp_type'] as String?,
        candidate: json['candidate'] as String?,
        sdpMid: json['sdp_mid'] as String?,
        sdpMLineIndex: json['sdp_mline_index'] as int?,
        errorCode: json['code'] as String?,
      );
}
