package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"time"
)

type ReadinessHandler struct {
	checker ReadinessChecker
	timeout time.Duration
}

func NewReadinessHandler(checker ReadinessChecker) *ReadinessHandler {
	return &ReadinessHandler{checker: checker, timeout: 2 * time.Second}
}

func (h *ReadinessHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if h.checker == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not_ready"})
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), h.timeout)
	defer cancel()
	if err := h.checker.Ping(ctx); err != nil {
		slog.WarnContext(ctx, "readiness check failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not_ready"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}
