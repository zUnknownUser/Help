package httpapi

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type ServiceRequestHandler struct{ lifecycle ports.ServiceRequestLifecycle }

func NewServiceRequestHandler(lifecycle ports.ServiceRequestLifecycle) *ServiceRequestHandler {
	return &ServiceRequestHandler{lifecycle: lifecycle}
}

func (handler *ServiceRequestHandler) List(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	page, err := handler.lifecycle.List(r.Context(), identity.UID, ports.ServiceRequestListInput{
		Role: r.URL.Query().Get("role"), Cursor: r.URL.Query().Get("cursor"), Limit: limit,
	})
	if err != nil {
		writeServiceRequestLifecycleError(w, r, err)
		return
	}
	items := make([]map[string]any, 0, len(page.Items))
	for _, request := range page.Items {
		items = append(items, newServiceRequestResponse(request))
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{
		"items": items, "next_cursor": page.NextCursor,
	}})
}

func (handler *ServiceRequestHandler) Agenda(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	items, err := handler.lifecycle.Agenda(r.Context(), identity.UID, ports.ServiceRequestAgendaInput{From: r.URL.Query().Get("from"), To: r.URL.Query().Get("to"), Limit: limit})
	if err != nil {
		writeServiceRequestLifecycleError(w, r, err)
		return
	}
	data := make([]map[string]any, 0, len(items))
	for _, item := range items {
		data = append(data, newServiceRequestResponse(item))
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"items": data}})
}

func (handler *ServiceRequestHandler) Details(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if _, err := uuid.Parse(r.PathValue("id")); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Solicitação inválida."})
		return
	}
	request, err := handler.lifecycle.Get(r.Context(), identity.UID, r.PathValue("id"))
	if err != nil {
		writeServiceRequestLifecycleError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newServiceRequestResponse(request)})
}

func (handler *ServiceRequestHandler) Transition(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if _, err := uuid.Parse(r.PathValue("id")); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Solicitação inválida."})
		return
	}
	var input struct {
		ClientCommandID string `json:"client_command_id"`
		TargetStatus    string `json:"target_status"`
		ExpectedVersion int    `json:"expected_version"`
		Reason          string `json:"reason"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Alteração inválida."})
		return
	}
	request, err := handler.lifecycle.Transition(r.Context(), identity.UID, r.PathValue("id"), ports.ServiceRequestTransitionInput{
		ClientCommandID: input.ClientCommandID, TargetStatus: input.TargetStatus,
		ExpectedVersion: input.ExpectedVersion, Reason: input.Reason,
	})
	if err != nil {
		writeServiceRequestLifecycleError(w, r, err)
		return
	}
	slog.InfoContext(r.Context(), "service request transitioned",
		"user_id", identity.UID, "request_id", request.ID,
		"status", request.Status, "version", request.Version,
	)
	writeJSON(w, http.StatusOK, map[string]any{"data": newServiceRequestResponse(request)})
}

func (handler *ServiceRequestHandler) Reschedule(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if _, err := uuid.Parse(r.PathValue("id")); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Solicitação inválida."})
		return
	}
	var input struct {
		ClientCommandID string `json:"client_command_id"`
		ScheduledFor    string `json:"scheduled_for"`
		ExpectedVersion int    `json:"expected_version"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Novo horário inválido."})
		return
	}
	request, err := handler.lifecycle.Reschedule(r.Context(), identity.UID, r.PathValue("id"), ports.ServiceRequestRescheduleInput{ClientCommandID: input.ClientCommandID, ScheduledFor: input.ScheduledFor, ExpectedVersion: input.ExpectedVersion})
	if errors.Is(err, domainrequests.ErrSlotUnavailable) {
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Esse horário não está mais disponível."})
		return
	}
	if err != nil {
		writeServiceRequestLifecycleError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": newServiceRequestResponse(request)})
}

func writeServiceRequestLifecycleError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, domainrequests.ErrNotFound):
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "Solicitação não encontrada."})
	case errors.Is(err, domainrequests.ErrForbidden):
		writeJSON(w, http.StatusForbidden, map[string]string{"message": "Você não pode realizar esta ação."})
	case errors.Is(err, domainrequests.ErrInvalidStatus), errors.Is(err, domainrequests.ErrInvalidTransition), errors.Is(err, domainrequests.ErrInvalidSchedule), errors.Is(err, domainrequests.ErrQuotePending):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Esta alteração não é permitida no estado atual."})
	case errors.Is(err, domainrequests.ErrVersionConflict):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "A solicitação foi atualizada em outro dispositivo. Recarregue e tente novamente."})
	case errors.Is(err, domainrequests.ErrIdempotencyConflict):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "Esta tentativa já foi usada em outra alteração."})
	default:
		slog.ErrorContext(r.Context(), "service request lifecycle failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível atualizar a solicitação agora."})
	}
}
