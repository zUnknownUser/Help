package ports

import (
	"context"
	"io"
	"time"

	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

type ChatRepository interface {
	FindOrCreateDirect(context.Context, string, string) (domainchat.Conversation, []string, bool, error)
	DecideConversation(context.Context, string, string, bool) (domainchat.Conversation, []string, bool, error)
	ListConversations(context.Context, string, string, int, string) (domainchat.ConversationPage, error)
	ListMessages(context.Context, string, string, int, *int64, *int64) (domainchat.MessagePage, error)
	CreateMessage(context.Context, string, domainchat.SendMessage) (domainchat.Message, []string, bool, error)
	EditMessage(context.Context, string, domainchat.MessageMutation) (domainchat.Message, []string, bool, error)
	DeleteMessage(context.Context, string, domainchat.MessageMutation) (domainchat.Message, []string, bool, error)
	AdvanceDelivered(context.Context, string, string, int64) ([]string, error)
	AdvanceRead(context.Context, string, string, int64) ([]string, error)
	ConversationRecipients(context.Context, string, string) ([]string, error)
	UpdateLastSeen(context.Context, string) (time.Time, error)
	UserPeerPresences(context.Context, string) ([]domainchat.Presence, error)
	PresencePolicy(context.Context, string) (domainchat.PresencePolicy, error)
}

type ChatMediaRepository interface {
	CreateMedia(context.Context, domainchat.MediaAsset) (domainchat.MediaAsset, error)
	GetMedia(context.Context, string, string) (domainchat.MediaAsset, error)
}

type MediaReader interface {
	io.Reader
	io.Seeker
	io.Closer
}

type StoredMedia struct {
	Key      string
	ByteSize int64
}

type MediaObject struct {
	Reader      MediaReader
	ContentType string
	ByteSize    int64
	ModifiedAt  time.Time
}

type ChatMediaStore interface {
	Save(context.Context, string, io.Reader, int64) (StoredMedia, error)
	Open(context.Context, string, string) (MediaObject, error)
	Delete(context.Context, string) error
}

type RealtimeEvent struct {
	Type string `json:"type"`
	Data any    `json:"data"`
}

type RealtimePublisher interface {
	Publish(userID string, event RealtimeEvent) int
	IsOnline(userID string) bool
}

type PushNotifier interface {
	NotifyNewMessage(context.Context, string, string) error
	NotifyConversationRequest(context.Context, string, string) error
}
