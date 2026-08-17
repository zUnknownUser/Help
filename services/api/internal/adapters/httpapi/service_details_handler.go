package httpapi

import (
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type ServiceDetailsHandler struct {
	details  ports.ServiceDetailsGetter
	requests ports.ServiceRequestCreator
}

func NewServiceDetailsHandler(details ports.ServiceDetailsGetter, requests ports.ServiceRequestCreator) *ServiceDetailsHandler {
	return &ServiceDetailsHandler{details: details, requests: requests}
}

func (handler *ServiceDetailsHandler) Details(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	details, err := handler.details.Execute(r.Context(), identity.UID, r.PathValue("id"))
	if errors.Is(err, catalog.ErrServiceNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "Serviço não encontrado."})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível carregar o serviço."})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newServiceDetailsResponse(details)})
}

func (handler *ServiceDetailsHandler) CreateRequest(w http.ResponseWriter, r *http.Request) {
	var input struct {
		ClientID     string `json:"client_request_id"`
		ScheduledFor string `json:"scheduled_for"`
		Note         string `json:"note"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Dados da solicitação inválidos."})
		return
	}
	identity, _ := authenticatedIdentity(r.Context())
	request, err := handler.requests.Execute(r.Context(), identity.UID, r.PathValue("id"), ports.ServiceRequestInput{
		ClientID: input.ClientID, ScheduledFor: input.ScheduledFor, Note: input.Note,
	})
	if err != nil {
		writeServiceRequestError(w, err)
		return
	}
	slog.InfoContext(r.Context(), "service request acknowledged",
		"user_id", identity.UID, "service_id", request.ServiceID,
		"client_request_id", request.ClientID, "request_id", request.ID,
		"provider_id", request.ProviderID, "status", request.Status,
	)
	writeJSON(w, http.StatusCreated, map[string]any{"data": newServiceRequestResponse(request)})
}

func writeServiceRequestError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, domainrequests.ErrInvalidClientID), errors.Is(err, domainrequests.ErrInvalidSchedule), errors.Is(err, domainrequests.ErrInvalidNote):
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Confira a data, o horário e a observação."})
	case errors.Is(err, domainrequests.ErrServiceUnavailable):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Este serviço não está disponível agora."})
	case errors.Is(err, domainrequests.ErrSlotUnavailable):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Esse horário acabou de ficar indisponível. Escolha outro horário."})
	case errors.Is(err, domainrequests.ErrCustomerRequired), errors.Is(err, domainrequests.ErrOwnService):
		writeJSON(w, http.StatusForbidden, map[string]string{"message": "Esta conta não pode solicitar esse serviço."})
	case errors.Is(err, domainrequests.ErrAddressRequired):
		writeJSON(w, http.StatusUnprocessableEntity, map[string]string{"message": "Defina um endereço com localização antes de solicitar."})
	case errors.Is(err, domainrequests.ErrIdempotencyConflict):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Esta tentativa já foi usada em outra solicitação."})
	default:
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível criar a solicitação."})
	}
}

func newServiceDetailsResponse(details catalog.Details) map[string]any {
	service := details.Service
	request := map[string]any{
		"can_request": details.CanRequest, "blocked_reason": details.RequestBlockedReason,
		"address": nil,
	}
	if details.ViewerAddress != nil {
		request["address"] = map[string]any{
			"label": details.ViewerAddress.Label, "formatted_address": details.ViewerAddress.FormattedAddress,
			"latitude": details.ViewerAddress.Latitude, "longitude": details.ViewerAddress.Longitude,
		}
	}
	return map[string]any{
		"id": service.ID, "title": service.Title, "description": service.Description,
		"category_id": service.CategoryID, "rating": service.Rating, "reviews": service.Reviews,
		"duration_minutes": service.DurationMinutes, "price_cents": service.PriceCents,
		"old_price_cents": service.OldPriceCents, "image_url": service.ImageURL,
		"image_alignment": service.ImageAlignment, "badge": service.Badge,
		"distance_km": service.DistanceKM, "service_area": details.ServiceArea,
		"provider": map[string]any{"id": service.ProviderID, "user_id": details.ProviderUserID, "name": details.ProviderName, "verified": details.ProviderVerified},
		"request":  request,
	}
}

func newServiceRequestResponse(request domainrequests.Request) map[string]any {
	available := domainrequests.AvailableTransitionsFor(request, time.Now())
	actions := make([]string, 0, len(available))
	for _, status := range available {
		actions = append(actions, string(status))
	}
	return map[string]any{
		"id": request.ID, "client_request_id": request.ClientID, "service_id": request.ServiceID,
		"service_title": request.ServiceTitle, "provider_id": request.ProviderID,
		"provider_name": request.ProviderName, "provider_user_id": request.ProviderUID,
		"customer_name": request.CustomerName, "customer_user_id": request.CustomerUID,
		"viewer_role": request.ViewerRole,
		"status":      request.Status, "status_reason": request.StatusReason,
		"version": request.Version, "available_actions": actions, "note": request.Note,
		"scheduled_for":      request.ScheduledFor.UTC().Format(time.RFC3339),
		"scheduled_end_at":   request.ScheduledEnd.UTC().Format(time.RFC3339),
		"quoted_price_cents": request.QuotedPriceCents,
		"address":            map[string]any{"label": request.AddressLabel, "formatted_address": request.Address},
		"created_at":         request.CreatedAt.UTC().Format(time.RFC3339),
		"updated_at":         request.UpdatedAt.UTC().Format(time.RFC3339),
	}
}
