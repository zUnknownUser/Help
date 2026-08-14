package ports

import (
	"context"

	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

type ChatRepository interface {
	FindOrCreateDirect(context.Context, string, string) (domainchat.Conversation, error)
	ListConversations(context.Context, string, string, int, string) (domainchat.ConversationPage, error)
	ListMessages(context.Context, string, string, int, *int64, *int64) (domainchat.MessagePage, error)
	CreateMessage(context.Context, string, domainchat.SendMessage) (domainchat.Message, []string, bool, error)
	AdvanceDelivered(context.Context, string, string, int64) ([]string, error)
	AdvanceRead(context.Context, string, string, int64) ([]string, error)
	ConversationRecipients(context.Context, string, string) ([]string, error)
	UserPeers(context.Context, string) ([]string, error)
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
}
