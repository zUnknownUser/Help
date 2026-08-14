package chat

import "time"

type Conversation struct {
	ID                  string    `json:"id"`
	OtherUserID         string    `json:"other_user_id"`
	OtherDisplayName    string    `json:"other_display_name"`
	LastMessage         *Message  `json:"last_message,omitempty"`
	LastReadSequence    int64     `json:"last_read_sequence"`
	LastMessageSequence int64     `json:"last_message_sequence"`
	UnreadCount         int       `json:"unread_count"`
	UpdatedAt           time.Time `json:"updated_at"`
}

type ConversationPage struct {
	Conversations []Conversation
	NextCursor    string
}
