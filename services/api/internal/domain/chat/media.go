package chat

import "time"

type MediaAsset struct {
	Media
	ConversationID string
	OwnerUID       string
	StorageKey     string
	CreatedAt      time.Time
}

var SupportedVoiceContentTypes = map[string]string{
	"audio/mp4":  ".m4a",
	"audio/aac":  ".aac",
	"audio/mpeg": ".mp3",
	"audio/ogg":  ".ogg",
	"audio/webm": ".webm",
}
