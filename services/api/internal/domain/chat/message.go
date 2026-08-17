package chat

import "time"

type MessageStatus string

type MessageKind string

const (
	StatusSent      MessageStatus = "sent"
	StatusDelivered MessageStatus = "delivered"
	StatusRead      MessageStatus = "read"
)

const (
	MessageText  MessageKind = "text"
	MessageVoice MessageKind = "voice"
)

type Media struct {
	ID          string `json:"id"`
	ContentType string `json:"content_type"`
	ByteSize    int64  `json:"byte_size"`
	DurationMS  int    `json:"duration_ms"`
}

type Message struct {
	ID             string        `json:"id"`
	ClientID       string        `json:"client_id"`
	ConversationID string        `json:"conversation_id"`
	SenderUID      string        `json:"sender_id"`
	Content        string        `json:"content"`
	Kind           MessageKind   `json:"kind"`
	Media          *Media        `json:"media,omitempty"`
	Sequence       int64         `json:"sequence"`
	CreatedAt      time.Time     `json:"created_at"`
	EditedAt       *time.Time    `json:"edited_at,omitempty"`
	DeletedAt      *time.Time    `json:"deleted_at,omitempty"`
	Version        int           `json:"version"`
	Status         MessageStatus `json:"status"`
}

type SendMessage struct {
	ConversationID string
	ClientID       string
	Content        string
	Kind           MessageKind
	MediaID        string
}

type MessagePage struct {
	Messages   []Message
	NextCursor string
}

type MessageMutation struct {
	OperationID string
	MessageID   string
	Content     string
}

type Presence struct {
	UserID        string     `json:"user_id"`
	Online        bool       `json:"online"`
	LastSeenAt    *time.Time `json:"last_seen_at,omitempty"`
	CanShowOnline bool       `json:"-"`
}

type PresencePolicy struct{ ShowOnline, ShowLastSeen bool }

type Receipt struct {
	ConversationID string `json:"conversation_id"`
	UserID         string `json:"user_id"`
	UpToSequence   int64  `json:"up_to_sequence"`
}
