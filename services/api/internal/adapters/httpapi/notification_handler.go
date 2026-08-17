package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/google/uuid"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type NotificationReadHandler struct{ marker ports.NotificationMarker }

func NewNotificationReadHandler(marker ports.NotificationMarker) *NotificationReadHandler {
	return &NotificationReadHandler{marker: marker}
}

func (handler *NotificationReadHandler) MarkAll(w http.ResponseWriter, r *http.Request) {
	identity, ok := authenticatedIdentity(r.Context())
	if !ok {
		writeUnauthorized(w)
		return
	}
	count, err := handler.marker.MarkAllRead(r.Context(), identity.UID)
	if err != nil {
		slog.ErrorContext(r.Context(), "mark all notifications read failed", "user_id", identity.UID, "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível atualizar as notificações agora."})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": map[string]int{"updated": count, "unread_count": 0}})
}

func (handler *NotificationReadHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	identity, ok := authenticatedIdentity(r.Context())
	if !ok {
		writeUnauthorized(w)
		return
	}
	id := r.PathValue("id")
	if _, err := uuid.Parse(id); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Notificação inválida."})
		return
	}
	if err := handler.marker.MarkRead(r.Context(), identity.UID, id); err != nil {
		slog.ErrorContext(r.Context(), "mark notification read failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"message": "Não foi possível atualizar a notificação agora.",
		})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
