package chat

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
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
	conversation, recipients, changed, err := service.repository.FindOrCreateDirect(ctx, userID, otherUserID)
	if err == nil && conversation.Status == domainchat.ConversationAccepted {
		conversation.OtherOnline = service.publisher.IsOnline(otherUserID)
	}
	if err == nil && changed {
		service.publishConversation(recipients, conversation)
		if conversation.Status == domainchat.ConversationPending && service.notifier != nil {
			for _, recipient := range recipients {
				if !service.publisher.IsOnline(recipient) {
					go service.notifyConversationRequest(recipient, conversation.ID)
				}
			}
		}
	}
	return conversation, err
}

func (service *Service) DecideConversation(
	ctx context.Context,
	userID, conversationID string,
	accept bool,
) (domainchat.Conversation, error) {
	conversation, recipients, changed, err := service.repository.DecideConversation(
		ctx, userID, conversationID, accept,
	)
	if err != nil {
		return domainchat.Conversation{}, err
	}
	if conversation.Status == domainchat.ConversationAccepted {
		conversation.OtherOnline = service.publisher.IsOnline(conversation.OtherUserID)
	}
	if changed {
		service.publishConversation(recipients, conversation)
	}
	return conversation, nil
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
	page, err := service.repository.ListConversations(
		ctx, userID, query, normalizedLimit(limit), cursor,
	)
	if err == nil {
		for index := range page.Conversations {
			conversation := &page.Conversations[index]
			if conversation.Status == domainchat.ConversationAccepted {
				conversation.OtherOnline = service.publisher.IsOnline(conversation.OtherUserID)
			} else {
				conversation.OtherLastSeenAt = nil
			}
		}
	}
	return page, err
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
	if message.Kind == "" {
		message.Kind = domainchat.MessageText
	}
	if _, err := uuid.Parse(message.ClientID); err != nil || !validMessagePayload(message) {
		return domainchat.Message{}, domainchat.ErrInvalidMessage
	}
	persisted, recipients, created, err := service.repository.CreateMessage(ctx, userID, message)
	if err != nil {
		return domainchat.Message{}, err
	}
	if created {
		event := ports.RealtimeEvent{Type: domainchat.EventMessageNew, Data: persisted}
		for _, recipient := range recipients {
			connections := service.publisher.Publish(recipient, event)
			if connections == 0 && service.notifier != nil {
				go service.notifyOffline(recipient, persisted.ConversationID)
			}
		}
	}
	return persisted, nil
}

func validMessagePayload(message domainchat.SendMessage) bool {
	switch message.Kind {
	case domainchat.MessageText:
		return len(message.Content) > 0 && len([]rune(message.Content)) <= 4000 && message.MediaID == ""
	case domainchat.MessageVoice:
		_, err := uuid.Parse(message.MediaID)
		return err == nil && message.Content == ""
	default:
		return false
	}
}

func (service *Service) Edit(
	ctx context.Context,
	userID string,
	mutation domainchat.MessageMutation,
) (domainchat.Message, error) {
	mutation.Content = strings.TrimSpace(mutation.Content)
	if err := validateMutation(mutation, true); err != nil {
		return domainchat.Message{}, err
	}
	message, recipients, changed, err := service.repository.EditMessage(ctx, userID, mutation)
	if err != nil {
		return domainchat.Message{}, err
	}
	if changed {
		service.publishMessage(domainchat.EventMessageUpdated, recipients, message)
	}
	return message, nil
}

func (service *Service) Delete(
	ctx context.Context,
	userID string,
	mutation domainchat.MessageMutation,
) (domainchat.Message, error) {
	if err := validateMutation(mutation, false); err != nil {
		return domainchat.Message{}, err
	}
	message, recipients, changed, err := service.repository.DeleteMessage(ctx, userID, mutation)
	if err != nil {
		return domainchat.Message{}, err
	}
	if changed {
		service.publishMessage(domainchat.EventMessageDeleted, recipients, message)
	}
	return message, nil
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
	service.publishReceipt(domainchat.EventMessageDelivered, recipients, domainchat.Receipt{
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
	service.publishReceipt(domainchat.EventMessageRead, recipients, domainchat.Receipt{
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
	eventType := domainchat.EventTypingStop
	if started {
		eventType = domainchat.EventTypingStart
	}
	for _, recipient := range recipients {
		service.publisher.Publish(recipient, ports.RealtimeEvent{
			Type: eventType,
			Data: map[string]any{"conversation_id": conversationID, "user_id": userID},
		})
	}
	return nil
}

func (service *Service) RelayCall(
	ctx context.Context,
	userID, eventType string,
	signal domainchat.CallSignal,
) error {
	if err := validateCallSignal(eventType, signal); err != nil {
		return err
	}
	recipients, err := service.repository.ConversationRecipients(
		ctx, userID, signal.ConversationID,
	)
	if err != nil {
		return err
	}
	signal.FromUserID = userID
	delivered := 0
	for _, recipient := range recipients {
		delivered += service.publisher.Publish(recipient, ports.RealtimeEvent{
			Type: eventType,
			Data: signal,
		})
	}
	if eventType == domainchat.EventCallInvite && delivered == 0 {
		return domainchat.ErrRecipientOffline
	}
	return nil
}

func (service *Service) SessionConnected(ctx context.Context, userID string) error {
	if _, err := service.repository.UpdateLastSeen(ctx, userID); err != nil {
		return err
	}
	peers, err := service.repository.UserPeerPresences(ctx, userID)
	if err != nil {
		return err
	}
	for _, peer := range peers {
		service.publisher.Publish(peer.UserID, presenceEvent(userID, true, nil))
		service.publisher.Publish(userID, presenceEvent(
			peer.UserID, service.publisher.IsOnline(peer.UserID), peer.LastSeenAt,
		))
	}
	return nil
}

func (service *Service) SessionDisconnected(ctx context.Context, userID string) error {
	if service.publisher.IsOnline(userID) {
		return nil
	}
	lastSeenAt, err := service.repository.UpdateLastSeen(ctx, userID)
	if err != nil {
		return err
	}
	peers, err := service.repository.UserPeerPresences(ctx, userID)
	if err != nil {
		return err
	}
	for _, peer := range peers {
		service.publisher.Publish(peer.UserID, presenceEvent(userID, false, &lastSeenAt))
	}
	return nil
}

func presenceEvent(userID string, online bool, lastSeenAt *time.Time) ports.RealtimeEvent {
	return ports.RealtimeEvent{Type: domainchat.EventPresenceChanged, Data: domainchat.Presence{
		UserID: userID, Online: online, LastSeenAt: lastSeenAt,
	}}
}

func (service *Service) publishMessage(
	eventType string,
	recipients []string,
	message domainchat.Message,
) {
	for _, recipient := range recipients {
		service.publisher.Publish(recipient, ports.RealtimeEvent{Type: eventType, Data: message})
	}
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

func (service *Service) publishConversation(
	recipients []string,
	conversation domainchat.Conversation,
) {
	for _, recipient := range recipients {
		service.publisher.Publish(recipient, ports.RealtimeEvent{
			Type: domainchat.EventConversationUpdated,
			Data: map[string]any{"conversation_id": conversation.ID},
		})
	}
}

func (service *Service) notifyOffline(userID, conversationID string) {
	ctx, cancel := context.WithTimeout(context.Background(), pushTimeout)
	defer cancel()
	if err := service.notifier.NotifyNewMessage(ctx, userID, conversationID); err != nil {
		slog.Warn("chat push failed", "user_id", userID, "conversation_id", conversationID, "error", err)
	}
}

func (service *Service) notifyConversationRequest(userID, conversationID string) {
	ctx, cancel := context.WithTimeout(context.Background(), pushTimeout)
	defer cancel()
	if err := service.notifier.NotifyConversationRequest(ctx, userID, conversationID); err != nil {
		slog.Warn("conversation request push failed", "user_id", userID,
			"conversation_id", conversationID, "error", err)
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

func validateMutation(mutation domainchat.MessageMutation, contentRequired bool) error {
	if _, err := uuid.Parse(mutation.OperationID); err != nil {
		return domainchat.ErrInvalidMessage
	}
	if _, err := uuid.Parse(mutation.MessageID); err != nil {
		return domainchat.ErrInvalidMessage
	}
	length := len([]rune(mutation.Content))
	if contentRequired && (length == 0 || length > 4000) {
		return domainchat.ErrInvalidMessage
	}
	return nil
}

func validateCallSignal(eventType string, signal domainchat.CallSignal) error {
	if !domainchat.IsCallEvent(eventType) {
		return domainchat.ErrInvalidCall
	}
	if _, err := uuid.Parse(signal.CallID); err != nil {
		return domainchat.ErrInvalidCall
	}
	if _, err := uuid.Parse(signal.ConversationID); err != nil {
		return domainchat.ErrInvalidCall
	}
	switch eventType {
	case domainchat.EventCallInvite:
		if signal.MediaType != domainchat.CallMediaAudio && signal.MediaType != domainchat.CallMediaVideo {
			return domainchat.ErrInvalidCall
		}
	case domainchat.EventCallOffer:
		if signal.SDPType != "offer" || len(signal.SDP) == 0 || len(signal.SDP) > 64<<10 {
			return domainchat.ErrInvalidCall
		}
	case domainchat.EventCallAnswer:
		if signal.SDPType != "answer" || len(signal.SDP) == 0 || len(signal.SDP) > 64<<10 {
			return domainchat.ErrInvalidCall
		}
	case domainchat.EventCallICE:
		if len(signal.Candidate) == 0 || len(signal.Candidate) > 8<<10 ||
			signal.SDPMLineIndex == nil || *signal.SDPMLineIndex < 0 {
			return domainchat.ErrInvalidCall
		}
	}
	return nil
}
