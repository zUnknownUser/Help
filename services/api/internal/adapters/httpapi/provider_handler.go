package httpapi

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type ProviderHandler struct {
	home    ports.ProviderHomeGetter
	manager ports.ProviderServiceManager
}

func NewProviderHandler(home ports.ProviderHomeGetter, manager ports.ProviderServiceManager) *ProviderHandler {
	return &ProviderHandler{home: home, manager: manager}
}

func (handler *ProviderHandler) Home(w http.ResponseWriter, r *http.Request) {
	uid, ok := authenticatedUID(w, r)
	if !ok {
		return
	}
	workspace, err := handler.home.Execute(r.Context(), uid)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	w.Header().Set("Cache-Control", "private, no-store")
	writeJSON(w, http.StatusOK, map[string]any{"data": newProviderHomeResponse(workspace)})
}

func (handler *ProviderHandler) CreateService(w http.ResponseWriter, r *http.Request) {
	uid, ok := authenticatedUID(w, r)
	if !ok {
		return
	}
	input, ok := decodeProviderServiceInput(w, r)
	if !ok {
		return
	}
	service, err := handler.manager.Create(r.Context(), uid, input)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"data": newManagedServiceResponse(service)})
}

func (handler *ProviderHandler) UpdateService(w http.ResponseWriter, r *http.Request) {
	uid, ok := authenticatedUID(w, r)
	if !ok {
		return
	}
	input, ok := decodeProviderServiceInput(w, r)
	if !ok {
		return
	}
	service, err := handler.manager.Update(r.Context(), uid, r.PathValue("id"), input)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newManagedServiceResponse(service)})
}

func (handler *ProviderHandler) SetPublication(w http.ResponseWriter, r *http.Request) {
	uid, ok := authenticatedUID(w, r)
	if !ok {
		return
	}
	var request publicationRequest
	if decodeJSONBody(w, r, &request) != nil {
		writeInvalidProviderInput(w)
		return
	}
	service, err := handler.manager.SetPublished(r.Context(), uid, r.PathValue("id"), request.Published)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newManagedServiceResponse(service)})
}

func (handler *ProviderHandler) DeleteService(w http.ResponseWriter, r *http.Request) {
	uid, ok := authenticatedUID(w, r)
	if !ok {
		return
	}
	if err := handler.manager.Delete(r.Context(), uid, r.PathValue("id")); err != nil {
		handler.writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (handler *ProviderHandler) SetAvailability(w http.ResponseWriter, r *http.Request) {
	uid, ok := authenticatedUID(w, r)
	if !ok {
		return
	}
	var request availabilityRequest
	if decodeJSONBody(w, r, &request) != nil {
		writeInvalidProviderInput(w)
		return
	}
	if err := handler.manager.SetAcceptingRequests(r.Context(), uid, request.AcceptingRequests); err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"accepting_requests": request.AcceptingRequests})
}

func (handler *ProviderHandler) writeError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, providers.ErrWorkspaceNotFound), errors.Is(err, providers.ErrServiceNotFound):
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "Recurso profissional não encontrado."})
	case errors.Is(err, providers.ErrProviderUnavailable):
		writeJSON(w, http.StatusForbidden, map[string]string{"message": "Seu perfil profissional ainda não está disponível."})
	case errors.Is(err, catalog.ErrInvalidServiceTitle),
		errors.Is(err, catalog.ErrInvalidServiceDescription),
		errors.Is(err, catalog.ErrInvalidServiceCategory),
		errors.Is(err, catalog.ErrInvalidServiceDuration),
		errors.Is(err, catalog.ErrInvalidServicePrice),
		errors.Is(err, catalog.ErrInvalidServiceImageURL):
		writeInvalidProviderInput(w)
	default:
		slog.ErrorContext(r.Context(), "provider workspace request failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível concluir a operação agora."})
	}
}

func authenticatedUID(w http.ResponseWriter, r *http.Request) (string, bool) {
	identity, ok := authenticatedIdentity(r.Context())
	if !ok {
		writeUnauthorized(w)
		return "", false
	}
	return identity.UID, true
}

func writeInvalidProviderInput(w http.ResponseWriter) {
	writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Revise os dados do serviço."})
}
