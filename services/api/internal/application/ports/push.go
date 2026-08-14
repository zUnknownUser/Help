package ports

import (
	"context"

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
}

type PushSender interface {
	SendNewMessage(context.Context, []string, string) ([]string, error)
}
