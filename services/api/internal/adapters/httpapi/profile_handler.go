package httpapi

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type ProfileHandler struct {
	registrar ports.ProfileRegistrar
	reader    ports.ProfileReader
}

func NewProfileHandler(
	registrar ports.ProfileRegistrar,
	reader ports.ProfileReader,
) *ProfileHandler {
	return &ProfileHandler{registrar: registrar, reader: reader}
}

func (handler *ProfileHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	identity, ok := authenticatedIdentity(r.Context())
	if !ok {
		writeUnauthorized(w)
		return
	}
	if r.Method == http.MethodGet {
		handler.get(w, r, identity.UID)
		return
	}
	handler.register(w, r, identity)
}

func (handler *ProfileHandler) get(w http.ResponseWriter, r *http.Request, uid string) {
	profile, err := handler.reader.FindByUID(r.Context(), uid)
	if errors.Is(err, domainprofiles.ErrProfileNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "Perfil não cadastrado."})
		return
	}
	if err != nil {
		slog.ErrorContext(r.Context(), "load profile failed", "error", err)
		writeProfileUnavailable(w)
		return
	}
	writeJSON(w, http.StatusOK, newProfileEnvelope(profile))
}

func (handler *ProfileHandler) register(
	w http.ResponseWriter,
	r *http.Request,
	identity ports.AuthenticatedIdentity,
) {
	var input struct {
		DisplayName string `json:"display_name"`
		Role        string `json:"role"`
	}
	if err := decodeJSONBody(w, r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Requisição inválida."})
		return
	}
	profile, err := handler.registrar.Execute(r.Context(), identity, ports.ProfileRegistrationInput{
		DisplayName: input.DisplayName,
		Role:        input.Role,
	})
	if errors.Is(err, domainprofiles.ErrInvalidDisplayName) ||
		errors.Is(err, domainprofiles.ErrInvalidRole) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Dados do perfil inválidos."})
		return
	}
	if err != nil {
		slog.ErrorContext(r.Context(), "register profile failed", "error", err)
		writeProfileUnavailable(w)
		return
	}
	writeJSON(w, http.StatusCreated, newProfileEnvelope(profile))
}

func writeProfileUnavailable(w http.ResponseWriter) {
	writeJSON(w, http.StatusServiceUnavailable, map[string]string{
		"message": "Não foi possível salvar o perfil agora.",
	})
}
