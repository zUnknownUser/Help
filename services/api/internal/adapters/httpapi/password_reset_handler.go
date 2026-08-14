package httpapi

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainauth "github.com/vendlydigital/help/services/api/internal/domain/auth"
)

const genericResetMessage = "Se existir uma conta para este e-mail, enviaremos as instruções de recuperação."

type PasswordResetHandler struct {
	requester ports.PasswordResetRequester
}

func NewPasswordResetHandler(requester ports.PasswordResetRequester) *PasswordResetHandler {
	return &PasswordResetHandler{requester: requester}
}

func (h *PasswordResetHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"message": "Método não permitido."})
		return
	}

	var input struct {
		Email string `json:"email"`
	}
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16<<10))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Requisição inválida."})
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Requisição inválida."})
		return
	}

	email, err := domainauth.ParseEmail(input.Email)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Informe um e-mail válido."})
		return
	}

	if err := h.requester.Execute(r.Context(), email); err != nil {
		slog.ErrorContext(r.Context(), "password reset request failed", "error", err)
	}

	writeJSON(w, http.StatusAccepted, map[string]string{"message": genericResetMessage})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		slog.Error("write json response", "error", err)
	}
}
