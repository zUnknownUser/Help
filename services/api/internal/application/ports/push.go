package ports

import (
	"context"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/devices"
)

type DeviceRepository interface {
	Upsert(context.Context, devices.Installation) error
	Disable(context.Context, string, string) error
	Tokens(context.Context, string) ([]string, error)
	DisableTokens(context.Context, []string) error
}

type NotificationRepository interface {
	CreateChatNotification(context.Context, string, string) error
	CreateConversationRequestNotification(context.Context, string, string) error
}

type PushNotification struct {
	Title string
	Body  string
	Data  map[string]string
	Badge int
}

type PushDelivery struct {
	NotificationID string
	UserID         string
	Attempts       int
	Message        PushNotification
}

type PushOutboxRepository interface {
	Claim(context.Context, int) ([]PushDelivery, error)
	MarkDelivered(context.Context, string) error
	Reschedule(context.Context, string, time.Time, string) error
}

type PushSender interface {
	Send(context.Context, []string, PushNotification) ([]string, error)
}

type ServiceRequestReminderRepository interface {
	EnqueueDueReminders(context.Context, time.Time, int) (int, error)
}
