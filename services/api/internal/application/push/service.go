package push

import (
	"context"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type Service struct {
	notifications ports.NotificationRepository
}

func NewService(notifications ports.NotificationRepository) *Service {
	return &Service{notifications: notifications}
}

func (service *Service) NotifyNewMessage(
	ctx context.Context,
	userID, conversationID string,
) error {
	return service.notifications.CreateChatNotification(ctx, userID, conversationID)
}

func (service *Service) NotifyConversationRequest(
	ctx context.Context,
	userID, conversationID string,
) error {
	return service.notifications.CreateConversationRequestNotification(
		ctx, userID, conversationID,
	)
}
