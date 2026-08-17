package chat

type CallMediaType string

const (
	CallMediaAudio CallMediaType = "audio"
	CallMediaVideo CallMediaType = "video"
)

type CallSignal struct {
	CallID         string        `json:"call_id"`
	ConversationID string        `json:"conversation_id"`
	FromUserID     string        `json:"from_user_id"`
	MediaType      CallMediaType `json:"media_type,omitempty"`
	SDP            string        `json:"sdp,omitempty"`
	SDPType        string        `json:"sdp_type,omitempty"`
	Candidate      string        `json:"candidate,omitempty"`
	SDPMid         string        `json:"sdp_mid,omitempty"`
	SDPMLineIndex  *int          `json:"sdp_mline_index,omitempty"`
}

func IsCallEvent(eventType string) bool {
	switch eventType {
	case EventCallInvite, EventCallRinging, EventCallAccept, EventCallReject,
		EventCallOffer, EventCallAnswer, EventCallICE, EventCallHangup, EventCallBusy:
		return true
	default:
		return false
	}
}
