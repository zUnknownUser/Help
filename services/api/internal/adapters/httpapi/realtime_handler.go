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

const (
	eventMessageSend      = "message.send"
	eventMessageAck       = "message.ack"
	eventMessageError     = "message.error"
	eventMessageDelivered = "message.delivered"
	eventMessageRead      = "message.read"
	eventTypingStart      = "typing.start"
	eventTypingStop       = "typing.stop"
	eventSessionReady     = "session.ready"
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
		Type: eventSessionReady, Data: map[string]string{"connection_id": connection.ID()},
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
	case eventMessageSend:
		handler.handleSend(ctx, connection, userID, event.Data)
	case eventMessageDelivered, eventMessageRead:
		handler.handleReceipt(ctx, connection, userID, event.Type, event.Data)
	case eventTypingStart, eventTypingStop:
		handler.handleTyping(ctx, connection, userID, event.Type == eventTypingStart, event.Data)
	default:
		connection.Enqueue(realtimeError("", "unsupported_event", false))
	}
}

func (handler *RealtimeHandler) handleSend(
	ctx context.Context,
	connection *realtime.Connection,
	userID string,
	payload json.RawMessage,
) {
	var request struct {
		ConversationID string `json:"conversation_id"`
		ClientID       string `json:"client_id"`
		Content        string `json:"content"`
	}
	if json.Unmarshal(payload, &request) != nil {
		connection.Enqueue(realtimeError("", "invalid_message", false))
		return
	}
	message, err := handler.service.Send(ctx, userID, domainchat.SendMessage{
		ConversationID: request.ConversationID, ClientID: request.ClientID, Content: request.Content,
	})
	if err != nil {
		connection.Enqueue(realtimeError(request.ClientID, chatErrorCode(err), isRetryableChatError(err)))
		return
	}
	connection.Enqueue(mustEvent(ports.RealtimeEvent{
		Type: eventMessageAck,
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
	if eventType == eventMessageRead {
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
	return mustEvent(ports.RealtimeEvent{Type: eventMessageError, Data: map[string]any{
		"client_id": clientID, "code": code, "retryable": retryable,
	}})
}

func chatErrorCode(err error) string {
	switch {
	case errors.Is(err, domainchat.ErrForbidden):
		return "forbidden"
	case errors.Is(err, domainchat.ErrConversationNotFound):
		return "conversation_not_found"
	case errors.Is(err, domainchat.ErrInvalidMessage):
		return "invalid_message"
	default:
		return "temporarily_unavailable"
	}
}

func isRetryableChatError(err error) bool {
	return !errors.Is(err, domainchat.ErrForbidden) &&
		!errors.Is(err, domainchat.ErrConversationNotFound) &&
		!errors.Is(err, domainchat.ErrInvalidMessage)
}
