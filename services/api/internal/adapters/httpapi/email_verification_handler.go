package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

const genericVerificationMessage = "Se o e-mail ainda não estiver confirmado, enviaremos um novo link."

type EmailVerificationHandler struct {
	requester ports.EmailVerificationRequester
}

func NewEmailVerificationHandler(
	requester ports.EmailVerificationRequester,
) *EmailVerificationHandler {
	return &EmailVerificationHandler{requester: requester}
}

func (handler *EmailVerificationHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	identity, ok := authenticatedIdentity(r.Context())
	if !ok {
		writeUnauthorized(w)
		return
	}
	if !identity.EmailVerified {
		if err := handler.requester.Execute(r.Context(), identity.Email); err != nil {
			slog.ErrorContext(r.Context(), "email verification request failed", "error", err)
			writeJSON(w, http.StatusServiceUnavailable, map[string]string{
				"message": "Não foi possível enviar a confirmação agora.",
			})
			return
		}
	}
	writeJSON(w, http.StatusAccepted, map[string]string{"message": genericVerificationMessage})
}
