package chat

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

const (
	EventMessageNew       = "message.new"
	EventMessageDelivered = "message.delivered"
	EventMessageRead      = "message.read"
	EventTypingStart      = "typing.start"
	EventTypingStop       = "typing.stop"
)

type Service struct {
	repository ports.ChatRepository
	publisher  ports.RealtimePublisher
	notifier   ports.PushNotifier
}

func NewService(
	repository ports.ChatRepository,
	publisher ports.RealtimePublisher,
	notifier ports.PushNotifier,
) *Service {
	return &Service{repository: repository, publisher: publisher, notifier: notifier}
}

func (service *Service) FindOrCreateDirect(
	ctx context.Context,
	userID, otherUserID string,
) (domainchat.Conversation, error) {
	if userID == otherUserID || strings.TrimSpace(otherUserID) == "" {
		return domainchat.Conversation{}, domainchat.ErrRecipientNotFound
	}
	return service.repository.FindOrCreateDirect(ctx, userID, otherUserID)
}

func (service *Service) ListConversations(
	ctx context.Context,
	userID, query string,
	limit int,
	cursor string,
) (domainchat.ConversationPage, error) {
	query = strings.TrimSpace(query)
	if len([]rune(query)) > 100 {
		return domainchat.ConversationPage{}, domainchat.ErrInvalidMessage
	}
	return service.repository.ListConversations(ctx, userID, query, normalizedLimit(limit), cursor)
}

func (service *Service) ListMessages(
	ctx context.Context,
	userID, conversationID string,
	limit int,
	before, after *int64,
) (domainchat.MessagePage, error) {
	return service.repository.ListMessages(
		ctx, userID, conversationID, normalizedLimit(limit), before, after,
	)
}

func (service *Service) Send(
	ctx context.Context,
	userID string,
	message domainchat.SendMessage,
) (domainchat.Message, error) {
	message.Content = strings.TrimSpace(message.Content)
	if _, err := uuid.Parse(message.ClientID); err != nil ||
		len(message.Content) == 0 || len([]rune(message.Content)) > 4000 {
		return domainchat.Message{}, domainchat.ErrInvalidMessage
	}
	persisted, recipients, created, err := service.repository.CreateMessage(ctx, userID, message)
	if err != nil {
		return domainchat.Message{}, err
	}
	if created {
		event := ports.RealtimeEvent{Type: EventMessageNew, Data: persisted}
		for _, recipient := range recipients {
			connections := service.publisher.Publish(recipient, event)
			if connections == 0 && service.notifier != nil {
				go service.notifyOffline(recipient, persisted.ConversationID)
			}
		}
	}
	return persisted, nil
}

func (service *Service) Delivered(
	ctx context.Context,
	userID, conversationID string,
	sequence int64,
) error {
	recipients, err := service.repository.AdvanceDelivered(ctx, userID, conversationID, sequence)
	if err != nil {
		return err
	}
	service.publishReceipt(EventMessageDelivered, recipients, domainchat.Receipt{
		ConversationID: conversationID, UserID: userID, UpToSequence: sequence,
	})
	return nil
}

func (service *Service) Read(
	ctx context.Context,
	userID, conversationID string,
	sequence int64,
) error {
	recipients, err := service.repository.AdvanceRead(ctx, userID, conversationID, sequence)
	if err != nil {
		return err
	}
	service.publishReceipt(EventMessageRead, recipients, domainchat.Receipt{
		ConversationID: conversationID, UserID: userID, UpToSequence: sequence,
	})
	return nil
}

func (service *Service) Typing(
	ctx context.Context,
	userID, conversationID string,
	started bool,
) error {
	recipients, err := service.repository.ConversationRecipients(ctx, userID, conversationID)
	if err != nil {
		return err
	}
	eventType := EventTypingStop
	if started {
		eventType = EventTypingStart
	}
	for _, recipient := range recipients {
		service.publisher.Publish(recipient, ports.RealtimeEvent{
			Type: eventType,
			Data: map[string]any{"conversation_id": conversationID, "user_id": userID},
		})
	}
	return nil
}

func (service *Service) SessionConnected(ctx context.Context, userID string) error {
	peers, err := service.repository.UserPeers(ctx, userID)
	if err != nil {
		return err
	}
	for _, peer := range peers {
		service.publisher.Publish(peer, presenceEvent(userID, true))
		service.publisher.Publish(userID, presenceEvent(peer, service.publisher.IsOnline(peer)))
	}
	return nil
}

func (service *Service) SessionDisconnected(ctx context.Context, userID string) error {
	if service.publisher.IsOnline(userID) {
		return nil
	}
	peers, err := service.repository.UserPeers(ctx, userID)
	if err != nil {
		return err
	}
	for _, peer := range peers {
		service.publisher.Publish(peer, presenceEvent(userID, false))
	}
	return nil
}

func presenceEvent(userID string, online bool) ports.RealtimeEvent {
	return ports.RealtimeEvent{Type: "presence.changed", Data: map[string]any{
		"user_id": userID, "online": online,
	}}
}

func (service *Service) publishReceipt(
	eventType string,
	recipients []string,
	receipt domainchat.Receipt,
) {
	for _, recipient := range recipients {
		service.publisher.Publish(recipient, ports.RealtimeEvent{Type: eventType, Data: receipt})
	}
}

func (service *Service) notifyOffline(userID, conversationID string) {
	ctx, cancel := context.WithTimeout(context.Background(), pushTimeout)
	defer cancel()
	if err := service.notifier.NotifyNewMessage(ctx, userID, conversationID); err != nil {
		slog.Warn("chat push failed", "user_id", userID, "conversation_id", conversationID, "error", err)
	}
}

func normalizedLimit(limit int) int {
	if limit < 1 {
		return 40
	}
	if limit > 100 {
		return 100
	}
	return limit
}

func validateSequence(sequence int64) error {
	if sequence < 1 {
		return fmt.Errorf("sequence must be positive: %w", domainchat.ErrInvalidMessage)
	}
	return nil
}
