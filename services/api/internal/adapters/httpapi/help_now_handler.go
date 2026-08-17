package httpapi

import (
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

type HelpNowHandler struct{ service ports.HelpNowService }

func NewHelpNowHandler(service ports.HelpNowService) *HelpNowHandler {
	return &HelpNowHandler{service: service}
}

func (handler *HelpNowHandler) Create(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	var input struct {
		ClientID     string  `json:"client_id"`
		CategoryID   string  `json:"category_id"`
		Note         string  `json:"note"`
		AddressLabel string  `json:"address_label"`
		Address      string  `json:"address"`
		Latitude     float64 `json:"latitude"`
		Longitude    float64 `json:"longitude"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Revise os dados do chamado."})
		return
	}
	request, err := handler.service.Create(r.Context(), identity.UID, ports.HelpNowCreateInput{
		ClientID: input.ClientID, CategoryID: input.CategoryID, Note: input.Note,
		AddressLabel: input.AddressLabel, Address: input.Address,
		Latitude: input.Latitude, Longitude: input.Longitude,
	})
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"data": newHelpNowRequestResponse(request)})
}

func (handler *HelpNowHandler) Active(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	request, err := handler.service.Active(r.Context(), identity.UID)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	if request == nil {
		writeJSON(w, http.StatusOK, map[string]any{"data": nil})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newHelpNowRequestResponse(*request)})
}

func (handler *HelpNowHandler) Cancel(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if _, err := uuid.Parse(r.PathValue("id")); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Chamado inválido."})
		return
	}
	request, err := handler.service.Cancel(r.Context(), identity.UID, r.PathValue("id"))
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newHelpNowRequestResponse(request)})
}

func (handler *HelpNowHandler) Availability(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	availability, err := handler.service.Availability(r.Context(), identity.UID)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newHelpNowAvailabilityResponse(availability)})
}

func (handler *HelpNowHandler) SetAvailability(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	var input struct {
		Enabled       bool    `json:"enabled"`
		Latitude      float64 `json:"latitude"`
		Longitude     float64 `json:"longitude"`
		MaxDistanceKM int     `json:"max_distance_km"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Disponibilidade inválida."})
		return
	}
	availability, err := handler.service.SetAvailability(r.Context(), identity.UID, ports.HelpNowAvailabilityInput{
		Enabled: input.Enabled, Latitude: input.Latitude, Longitude: input.Longitude,
		MaxDistanceKM: input.MaxDistanceKM,
	})
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newHelpNowAvailabilityResponse(availability)})
}

func (handler *HelpNowHandler) Offers(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	offers, err := handler.service.Offers(r.Context(), identity.UID)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	items := make([]map[string]any, 0, len(offers))
	for _, offer := range offers {
		items = append(items, map[string]any{
			"id": offer.ID, "request_id": offer.RequestID, "category_id": offer.CategoryID,
			"category_name": offer.CategoryName, "note": offer.Note, "area": offer.Area,
			"distance_meters": offer.DistanceMeters, "wave": offer.Wave,
			"offered_at": offer.OfferedAt.UTC().Format(time.RFC3339Nano),
			"expires_at": offer.ExpiresAt.UTC().Format(time.RFC3339Nano),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"items": items}})
}

func (handler *HelpNowHandler) Respond(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	var input struct {
		ClientCommandID string `json:"client_command_id"`
		Action          string `json:"action"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Resposta inválida."})
		return
	}
	request, err := handler.service.Respond(r.Context(), identity.UID, ports.HelpNowOfferResponseInput{
		ClientCommandID: input.ClientCommandID, OfferID: r.PathValue("id"), Action: input.Action,
	})
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newHelpNowRequestResponse(request)})
}

func (handler *HelpNowHandler) writeError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, domainhelp.ErrInvalidInput):
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Revise os dados informados."})
	case errors.Is(err, domainhelp.ErrActiveRequest):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Você já possui um chamado sendo procurado."})
	case errors.Is(err, domainhelp.ErrRateLimited):
		w.Header().Set("Retry-After", "900")
		writeJSON(w, http.StatusTooManyRequests, map[string]string{"message": "Aguarde alguns minutos antes de iniciar outra busca."})
	case errors.Is(err, domainhelp.ErrNotFound):
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "Chamado não encontrado."})
	case errors.Is(err, domainhelp.ErrForbidden), errors.Is(err, domainhelp.ErrProviderIneligible):
		writeJSON(w, http.StatusForbidden, map[string]string{"message": "Seu perfil ainda não pode usar esta função."})
	case errors.Is(err, domainhelp.ErrOfferExpired), errors.Is(err, domainhelp.ErrAlreadyAssigned), errors.Is(err, domainhelp.ErrProviderBusy):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Este chamado não está mais disponível."})
	case errors.Is(err, domainhelp.ErrIdempotency):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Esta tentativa já foi utilizada."})
	default:
		slog.ErrorContext(r.Context(), "help now request failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível concluir agora."})
	}
}

func newHelpNowRequestResponse(request domainhelp.Request) map[string]any {
	return map[string]any{
		"id": request.ID, "client_id": request.ClientID, "category_id": request.CategoryID,
		"category_name": request.CategoryName, "note": request.Note, "status": request.Status,
		"address_label": request.AddressLabel, "address": request.Address,
		"latitude": request.Latitude, "longitude": request.Longitude, "wave": request.Wave,
		"assigned_provider_id":   request.AssignedProviderID,
		"assigned_provider_name": request.AssignedProviderName,
		"service_request_id":     request.ServiceRequestID,
		"created_at":             request.CreatedAt.UTC().Format(time.RFC3339Nano),
		"updated_at":             request.UpdatedAt.UTC().Format(time.RFC3339Nano),
		"search_expires_at":      request.SearchExpiresAt.UTC().Format(time.RFC3339Nano),
	}
}

func newHelpNowAvailabilityResponse(value domainhelp.Availability) map[string]any {
	return map[string]any{"enabled": value.Enabled, "latitude": value.Latitude,
		"longitude": value.Longitude, "max_distance_km": value.MaxDistanceKM,
		"heartbeat_at": value.HeartbeatAt.UTC().Format(time.RFC3339Nano),
		"expires_at":   value.ExpiresAt.UTC().Format(time.RFC3339Nano)}
}
