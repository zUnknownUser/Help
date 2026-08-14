package httpapi

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	applicationchat "github.com/vendlydigital/help/services/api/internal/application/chat"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

type ChatHandler struct{ service *applicationchat.Service }

func NewChatHandler(service *applicationchat.Service) *ChatHandler {
	return &ChatHandler{service: service}
}

func (handler *ChatHandler) DirectConversation(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	var request struct {
		OtherUserID string `json:"other_user_id"`
	}
	if decodeJSONBody(w, r, &request) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Requisição inválida."})
		return
	}
	conversation, err := handler.service.FindOrCreateDirect(r.Context(), identity.UID, request.OtherUserID)
	if err != nil {
		writeChatError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": conversation})
}

func (handler *ChatHandler) Conversations(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	page, err := handler.service.ListConversations(
		r.Context(), identity.UID, r.URL.Query().Get("query"), queryLimit(r),
		r.URL.Query().Get("cursor"),
	)
	if err != nil {
		writeChatError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"data": page.Conversations, "next_cursor": page.NextCursor,
	})
}

func (handler *ChatHandler) Messages(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	before, beforeErr := optionalInt64(r.URL.Query().Get("before_sequence"))
	after, afterErr := optionalInt64(r.URL.Query().Get("after_sequence"))
	if beforeErr != nil || afterErr != nil || (before != nil && after != nil) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Cursor de mensagens inválido."})
		return
	}
	page, err := handler.service.ListMessages(
		r.Context(), identity.UID, r.PathValue("id"), queryLimit(r), before, after,
	)
	if err != nil {
		writeChatError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"data": page.Messages, "next_cursor": page.NextCursor,
	})
}

func queryLimit(r *http.Request) int {
	value, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	return value
}

func optionalInt64(value string) (*int64, error) {
	if strings.TrimSpace(value) == "" {
		return nil, nil
	}
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil || parsed < 1 {
		return nil, errors.New("invalid cursor")
	}
	return &parsed, nil
}

func writeChatError(w http.ResponseWriter, err error) {
	status := http.StatusInternalServerError
	message := "Não foi possível concluir a operação de conversa."
	switch {
	case errors.Is(err, domainchat.ErrForbidden):
		status, message = http.StatusForbidden, "Você não participa desta conversa."
	case errors.Is(err, domainchat.ErrConversationNotFound):
		status, message = http.StatusNotFound, "Conversa não encontrada."
	case errors.Is(err, domainchat.ErrRecipientNotFound):
		status, message = http.StatusNotFound, "Destinatário não encontrado."
	case errors.Is(err, domainchat.ErrInvalidMessage):
		status, message = http.StatusBadRequest, "Mensagem inválida."
	case strings.Contains(err.Error(), "cursor"):
		status, message = http.StatusBadRequest, "Cursor inválido."
	}
	writeJSON(w, status, map[string]string{"message": message})
}
