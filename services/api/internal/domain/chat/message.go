package chat

import "time"

type MessageStatus string

const (
	StatusSent      MessageStatus = "sent"
	StatusDelivered MessageStatus = "delivered"
	StatusRead      MessageStatus = "read"
)

type Message struct {
	ID             string        `json:"id"`
	ClientID       string        `json:"client_id"`
	ConversationID string        `json:"conversation_id"`
	SenderUID      string        `json:"sender_id"`
	Content        string        `json:"content"`
	Sequence       int64         `json:"sequence"`
	CreatedAt      time.Time     `json:"created_at"`
	Status         MessageStatus `json:"status"`
}

type SendMessage struct {
	ConversationID string
	ClientID       string
	Content        string
}

type MessagePage struct {
	Messages   []Message
	NextCursor string
}

type Receipt struct {
	ConversationID string `json:"conversation_id"`
	UserID         string `json:"user_id"`
	UpToSequence   int64  `json:"up_to_sequence"`
}
