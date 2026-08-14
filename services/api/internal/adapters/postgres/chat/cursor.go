package chat

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"time"
)

type conversationCursor struct {
	UpdatedAt time.Time `json:"updated_at"`
	ID        string    `json:"id"`
}

func encodeConversationCursor(cursor conversationCursor) string {
	encoded, _ := json.Marshal(cursor)
	return base64.RawURLEncoding.EncodeToString(encoded)
}

func decodeConversationCursor(value string) (*conversationCursor, error) {
	if value == "" {
		return nil, nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return nil, errors.New("invalid conversation cursor")
	}
	var cursor conversationCursor
	if err := json.Unmarshal(raw, &cursor); err != nil || cursor.ID == "" || cursor.UpdatedAt.IsZero() {
		return nil, errors.New("invalid conversation cursor")
	}
	return &cursor, nil
}
