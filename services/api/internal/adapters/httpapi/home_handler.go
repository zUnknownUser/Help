package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type HomeHandler struct{ getter ports.HomeGetter }

func NewHomeHandler(getter ports.HomeGetter) *HomeHandler {
	return &HomeHandler{getter: getter}
}

func (h *HomeHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	content, err := h.getter.Execute(r.Context())
	if err != nil {
		slog.ErrorContext(r.Context(), "load home failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"message": "Não foi possível carregar a página inicial agora.",
		})
		return
	}
	w.Header().Set("Cache-Control", "private, max-age=30")
	writeJSON(w, http.StatusOK, newHomeResponse(content))
}
