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
	updater   ports.ProfileUpdater
	emailSync ports.ProfileEmailSynchronizer
}

type profileProfessionalRequest struct {
	Title           string `json:"title"`
	Bio             string `json:"bio"`
	YearsExperience *int   `json:"years_experience"`
	ServiceRadiusKM int    `json:"service_radius_km"`
}

func NewProfileHandler(
	registrar ports.ProfileRegistrar,
	reader ports.ProfileReader,
	updater ports.ProfileUpdater,
	emailSync ports.ProfileEmailSynchronizer,
) *ProfileHandler {
	return &ProfileHandler{registrar: registrar, reader: reader, updater: updater, emailSync: emailSync}
}

func (handler *ProfileHandler) SyncEmail(w http.ResponseWriter, r *http.Request) {
	identity, ok := authenticatedIdentity(r.Context())
	if !ok {
		writeUnauthorized(w)
		return
	}
	profile, err := handler.emailSync.Execute(r.Context(), identity)
	if errors.Is(err, domainprofiles.ErrProfileNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "Perfil não cadastrado."})
		return
	}
	if err != nil {
		slog.ErrorContext(r.Context(), "sync profile email failed", "user_id", identity.UID, "error", err)
		writeProfileUnavailable(w)
		return
	}
	writeJSON(w, http.StatusOK, newProfileEnvelope(profile))
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
	if r.Method == http.MethodPut {
		handler.update(w, r, identity.UID)
		return
	}
	handler.register(w, r, identity)
}

func (handler *ProfileHandler) update(w http.ResponseWriter, r *http.Request, uid string) {
	var input struct {
		DisplayName               string                      `json:"display_name"`
		Phone                     string                      `json:"phone"`
		ContactPreference         string                      `json:"contact_preference"`
		PhotoVisibility           string                      `json:"photo_visibility"`
		LastSeenVisibility        string                      `json:"last_seen_visibility"`
		ShowOnline                bool                        `json:"show_online"`
		AllowConversationRequests bool                        `json:"allow_conversation_requests"`
		Professional              *profileProfessionalRequest `json:"professional"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Revise os dados do perfil."})
		return
	}
	profile, err := handler.updater.Execute(r.Context(), uid, ports.ProfileUpdateInput{
		DisplayName: input.DisplayName, Phone: input.Phone,
		ContactPreference: input.ContactPreference, PhotoVisibility: input.PhotoVisibility,
		LastSeenVisibility: input.LastSeenVisibility, ShowOnline: input.ShowOnline,
		AllowConversationRequests: input.AllowConversationRequests,
		Professional:              professionalProfileInput(input.Professional),
	})
	if errors.Is(err, domainprofiles.ErrInvalidDisplayName) || errors.Is(err, domainprofiles.ErrInvalidProfileDetails) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Revise os dados do perfil."})
		return
	}
	if err != nil {
		slog.ErrorContext(r.Context(), "update profile failed", "user_id", uid, "error", err)
		writeProfileUnavailable(w)
		return
	}
	writeJSON(w, http.StatusOK, newProfileEnvelope(profile))
}

func professionalProfileInput(input *profileProfessionalRequest) *ports.ProfessionalProfileInput {
	if input == nil {
		return nil
	}
	return &ports.ProfessionalProfileInput{Title: input.Title, Bio: input.Bio,
		YearsExperience: input.YearsExperience, ServiceRadiusKM: input.ServiceRadiusKM}
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
	slog.InfoContext(r.Context(), "profile registered", "user_id", identity.UID, "role", input.Role)
	writeJSON(w, http.StatusCreated, newProfileEnvelope(profile))
}

func writeProfileUnavailable(w http.ResponseWriter) {
	writeJSON(w, http.StatusServiceUnavailable, map[string]string{
		"message": "Não foi possível salvar o perfil agora.",
	})
}
