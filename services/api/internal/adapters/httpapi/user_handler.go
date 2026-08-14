package httpapi

import (
	"net/http"
	"strings"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type UserHandler struct{ directory ports.UserDirectory }

func NewUserHandler(directory ports.UserDirectory) *UserHandler {
	return &UserHandler{directory: directory}
}

func (handler *UserHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	page, err := handler.directory.SearchUsers(
		r.Context(), identity.UID, r.URL.Query().Get("query"), queryLimit(r), r.URL.Query().Get("cursor"),
	)
	if err != nil {
		if strings.Contains(err.Error(), "cursor") {
			writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Cursor inválido."})
			return
		}
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível buscar usuários."})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": page.Users, "next_cursor": page.NextCursor})
}
