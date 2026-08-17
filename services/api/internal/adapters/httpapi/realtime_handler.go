package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/coder/websocket"

	"github.com/vendlydigital/help/services/api/internal/adapters/realtime"
	applicationchat "github.com/vendlydigital/help/services/api/internal/application/chat"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

type RealtimeHandler struct {
	hub     *realtime.Hub
	service *applicationchat.Service
}

func NewRealtimeHandler(hub *realtime.Hub, service *applicationchat.Service) *RealtimeHandler {
	return &RealtimeHandler{hub: hub, service: service}
}

func (handler *RealtimeHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	socket, err := websocket.Accept(w, r, &websocket.AcceptOptions{InsecureSkipVerify: true})
	if err != nil {
		return
	}
	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()
	connection := realtime.Accept(ctx, socket, identity.UID)
	handler.hub.Register(connection)
	_ = handler.service.SessionConnected(ctx, identity.UID)
	defer func() {
		handler.hub.Unregister(connection)
		disconnectCtx, disconnectCancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer disconnectCancel()
		_ = handler.service.SessionDisconnected(disconnectCtx, identity.UID)
		connection.Close()
		slog.Info("realtime disconnected", "connection_id", connection.ID(), "user_id", identity.UID)
	}()
	slog.Info("realtime connected", "connection_id", connection.ID(), "user_id", identity.UID)
	connection.Enqueue(mustEvent(ports.RealtimeEvent{
		Type: domainchat.EventSessionReady, Data: map[string]string{"connection_id": connection.ID()},
	}))
	go func() {
		_ = connection.WriteLoop(ctx)
		cancel()
	}()
	for {
		payload, readErr := connection.Read(ctx)
		if readErr != nil {
			return
		}
		handler.handleEvent(ctx, connection, identity.UID, payload)
	}
}

type inboundEvent struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data"`
}

func (handler *RealtimeHandler) handleEvent(
	ctx context.Context,
	connection *realtime.Connection,
	userID string,
	payload []byte,
) {
	var event inboundEvent
	if err := json.Unmarshal(payload, &event); err != nil {
		connection.Enqueue(realtimeError("", "invalid_event", false))
		return
	}
	switch event.Type {
	case domainchat.EventMessageSend:
		handler.handleSend(ctx, connection, userID, event.Data)
	case domainchat.EventMessageDelivered, domainchat.EventMessageRead:
		handler.handleReceipt(ctx, connection, userID, event.Type, event.Data)
	case domainchat.EventMessageEdit, domainchat.EventMessageDelete:
		handler.handleMutation(ctx, connection, userID, event.Type, event.Data)
	case domainchat.EventTypingStart, domainchat.EventTypingStop:
		handler.handleTyping(ctx, connection, userID, event.Type == domainchat.EventTypingStart, event.Data)
	case domainchat.EventCallInvite, domainchat.EventCallRinging,
		domainchat.EventCallAccept, domainchat.EventCallReject,
		domainchat.EventCallOffer, domainchat.EventCallAnswer,
		domainchat.EventCallICE, domainchat.EventCallHangup, domainchat.EventCallBusy:
		handler.handleCall(ctx, connection, userID, event.Type, event.Data)
	default:
		connection.Enqueue(realtimeError("", "unsupported_event", false))
	}
}

func (handler *RealtimeHandler) handleCall(
	ctx context.Context,
	connection *realtime.Connection,
	userID, eventType string,
	payload json.RawMessage,
) {
	var signal domainchat.CallSignal
	if json.Unmarshal(payload, &signal) != nil {
		connection.Enqueue(callError("", "", "invalid_call"))
		return
	}
	if err := handler.service.RelayCall(ctx, userID, eventType, signal); err != nil {
		connection.Enqueue(callError(signal.CallID, signal.ConversationID, chatErrorCode(err)))
		return
	}
	slog.Info("call signal relayed",
		"connection_id", connection.ID(), "user_id", userID,
		"conversation_id", signal.ConversationID, "call_id", signal.CallID,
		"event_type", eventType,
	)
}

func (handler *RealtimeHandler) handleMutation(
	ctx context.Context,
	connection *realtime.Connection,
	userID, eventType string,
	payload json.RawMessage,
) {
	var request struct {
		OperationID string `json:"operation_id"`
		MessageID   string `json:"message_id"`
		Content     string `json:"content"`
	}
	if json.Unmarshal(payload, &request) != nil {
		connection.Enqueue(mutationError("", "invalid_message", false))
		return
	}
	mutation := domainchat.MessageMutation{
		OperationID: request.OperationID,
		MessageID:   request.MessageID,
		Content:     request.Content,
	}
	var (
		message domainchat.Message
		err     error
	)
	if eventType == domainchat.EventMessageDelete {
		message, err = handler.service.Delete(ctx, userID, mutation)
	} else {
		message, err = handler.service.Edit(ctx, userID, mutation)
	}
	if err != nil {
		connection.Enqueue(mutationError(
			request.OperationID, chatErrorCode(err), isRetryableChatError(err),
		))
		return
	}
	connection.Enqueue(mustEvent(ports.RealtimeEvent{
		Type: domainchat.EventMutationAck,
		Data: map[string]any{"operation_id": request.OperationID, "message": message},
	}))
	slog.Info("message mutation acknowledged",
		"connection_id", connection.ID(), "user_id", userID,
		"conversation_id", message.ConversationID,
		"server_message_id", message.ID, "operation_id", request.OperationID,
		"version", message.Version,
	)
}

func (handler *RealtimeHandler) handleSend(
	ctx context.Context,
	connection *realtime.Connection,
	userID string,
	payload json.RawMessage,
) {
	var request struct {
		ConversationID string                 `json:"conversation_id"`
		ClientID       string                 `json:"client_id"`
		Content        string                 `json:"content"`
		Kind           domainchat.MessageKind `json:"kind"`
		MediaID        string                 `json:"media_id"`
	}
	if json.Unmarshal(payload, &request) != nil {
		connection.Enqueue(realtimeError("", "invalid_message", false))
		return
	}
	message, err := handler.service.Send(ctx, userID, domainchat.SendMessage{
		ConversationID: request.ConversationID, ClientID: request.ClientID,
		Content: request.Content, Kind: request.Kind, MediaID: request.MediaID,
	})
	if err != nil {
		connection.Enqueue(realtimeError(request.ClientID, chatErrorCode(err), isRetryableChatError(err)))
		return
	}
	connection.Enqueue(mustEvent(ports.RealtimeEvent{
		Type: domainchat.EventMessageAck,
		Data: map[string]any{"client_id": request.ClientID, "message": message},
	}))
	slog.Info("message acknowledged",
		"connection_id", connection.ID(), "user_id", userID,
		"conversation_id", message.ConversationID, "client_message_id", message.ClientID,
		"server_message_id", message.ID, "sequence", message.Sequence,
	)
}

func (handler *RealtimeHandler) handleReceipt(
	ctx context.Context,
	connection *realtime.Connection,
	userID, eventType string,
	payload json.RawMessage,
) {
	var receipt struct {
		ConversationID string `json:"conversation_id"`
		UpToSequence   int64  `json:"up_to_sequence"`
	}
	if json.Unmarshal(payload, &receipt) != nil || receipt.UpToSequence < 1 {
		connection.Enqueue(realtimeError("", "invalid_receipt", false))
		return
	}
	var err error
	if eventType == domainchat.EventMessageRead {
		err = handler.service.Read(ctx, userID, receipt.ConversationID, receipt.UpToSequence)
	} else {
		err = handler.service.Delivered(ctx, userID, receipt.ConversationID, receipt.UpToSequence)
	}
	if err != nil {
		connection.Enqueue(realtimeError("", chatErrorCode(err), false))
	}
}

func (handler *RealtimeHandler) handleTyping(
	ctx context.Context,
	connection *realtime.Connection,
	userID string,
	started bool,
	payload json.RawMessage,
) {
	var typing struct {
		ConversationID string `json:"conversation_id"`
	}
	if json.Unmarshal(payload, &typing) != nil || typing.ConversationID == "" {
		connection.Enqueue(realtimeError("", "invalid_typing", false))
		return
	}
	if err := handler.service.Typing(ctx, userID, typing.ConversationID, started); err != nil {
		connection.Enqueue(realtimeError("", chatErrorCode(err), false))
	}
}

func mustEvent(event ports.RealtimeEvent) []byte {
	payload, _ := json.Marshal(event)
	return payload
}

func realtimeError(clientID, code string, retryable bool) []byte {
	return mustEvent(ports.RealtimeEvent{Type: domainchat.EventMessageError, Data: map[string]any{
		"client_id": clientID, "code": code, "retryable": retryable,
	}})
}

func mutationError(operationID, code string, retryable bool) []byte {
	return mustEvent(ports.RealtimeEvent{Type: domainchat.EventMutationError, Data: map[string]any{
		"operation_id": operationID, "code": code, "retryable": retryable,
	}})
}

func callError(callID, conversationID, code string) []byte {
	return mustEvent(ports.RealtimeEvent{Type: domainchat.EventCallError, Data: map[string]any{
		"call_id": callID, "conversation_id": conversationID, "code": code,
	}})
}

func chatErrorCode(err error) string {
	switch {
	case errors.Is(err, domainchat.ErrForbidden):
		return "forbidden"
	case errors.Is(err, domainchat.ErrConversationNotFound):
		return "conversation_not_found"
	case errors.Is(err, domainchat.ErrMessageNotFound):
		return "message_not_found"
	case errors.Is(err, domainchat.ErrInvalidMessage):
		return "invalid_message"
	case errors.Is(err, domainchat.ErrConversationPending):
		return "conversation_pending"
	case errors.Is(err, domainchat.ErrRecipientOffline):
		return "recipient_offline"
	case errors.Is(err, domainchat.ErrInvalidCall):
		return "invalid_call"
	case errors.Is(err, domainchat.ErrInvalidMedia), errors.Is(err, domainchat.ErrMediaNotFound):
		return "invalid_media"
	default:
		return "temporarily_unavailable"
	}
}

func isRetryableChatError(err error) bool {
	return !errors.Is(err, domainchat.ErrForbidden) &&
		!errors.Is(err, domainchat.ErrConversationNotFound) &&
		!errors.Is(err, domainchat.ErrMessageNotFound) &&
		!errors.Is(err, domainchat.ErrConversationPending) &&
		!errors.Is(err, domainchat.ErrInvalidMessage) &&
		!errors.Is(err, domainchat.ErrInvalidMedia) &&
		!errors.Is(err, domainchat.ErrMediaNotFound)
}
