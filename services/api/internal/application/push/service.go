package push

import (
	"context"
	"fmt"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type Service struct {
	devices       ports.DeviceRepository
	notifications ports.NotificationRepository
	sender        ports.PushSender
}

func NewService(
	devices ports.DeviceRepository,
	notifications ports.NotificationRepository,
	sender ports.PushSender,
) *Service {
	return &Service{devices: devices, notifications: notifications, sender: sender}
}

func (service *Service) NotifyNewMessage(
	ctx context.Context,
	userID, conversationID string,
) error {
	if err := service.notifications.CreateChatNotification(ctx, userID, conversationID); err != nil {
		return err
	}
	tokens, err := service.devices.Tokens(ctx, userID)
	if err != nil || len(tokens) == 0 {
		return err
	}
	invalid, err := service.sender.SendNewMessage(ctx, tokens, conversationID)
	if disableErr := service.devices.DisableTokens(ctx, invalid); disableErr != nil && err == nil {
		err = disableErr
	}
	if err != nil {
		return fmt.Errorf("deliver new message push: %w", err)
	}
	return nil
}
