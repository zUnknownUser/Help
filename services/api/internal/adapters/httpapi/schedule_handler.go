package httpapi

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/scheduling"
)

type ScheduleHandler struct {
	manager      ports.ProviderScheduleManager
	availability ports.ServiceAvailability
}

func NewScheduleHandler(manager ports.ProviderScheduleManager, availability ports.ServiceAvailability) *ScheduleHandler {
	return &ScheduleHandler{manager: manager, availability: availability}
}

func (handler *ScheduleHandler) Get(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	plan, err := handler.manager.Get(r.Context(), identity.UID)
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": scheduleResponse(plan)})
}

func (handler *ScheduleHandler) Replace(w http.ResponseWriter, r *http.Request) {
	var input struct {
		ExpectedVersion      int    `json:"expected_version"`
		TimeZone             string `json:"time_zone"`
		MinimumNoticeMinutes int    `json:"minimum_notice_minutes"`
		BookingHorizonDays   int    `json:"booking_horizon_days"`
		BufferMinutes        int    `json:"buffer_minutes"`
		SlotIntervalMinutes  int    `json:"slot_interval_minutes"`
		Rules                []struct {
			Weekday     int `json:"weekday"`
			StartMinute int `json:"start_minute"`
			EndMinute   int `json:"end_minute"`
		} `json:"rules"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		handler.writeError(w, r, scheduling.ErrInvalidSchedule)
		return
	}
	rules := make([]scheduling.Rule, 0, len(input.Rules))
	for _, rule := range input.Rules {
		rules = append(rules, scheduling.Rule{Weekday: rule.Weekday, StartMinute: rule.StartMinute, EndMinute: rule.EndMinute})
	}
	identity, _ := authenticatedIdentity(r.Context())
	plan, err := handler.manager.Replace(r.Context(), identity.UID, ports.ProviderScheduleInput{ExpectedVersion: input.ExpectedVersion, TimeZone: input.TimeZone, MinimumNoticeMinutes: input.MinimumNoticeMinutes, BookingHorizonDays: input.BookingHorizonDays, BufferMinutes: input.BufferMinutes, SlotIntervalMinutes: input.SlotIntervalMinutes, Rules: rules})
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": scheduleResponse(plan)})
}

func (handler *ScheduleHandler) AddBlock(w http.ResponseWriter, r *http.Request) {
	var input struct {
		StartsAt string `json:"starts_at"`
		EndsAt   string `json:"ends_at"`
		Reason   string `json:"reason"`
	}
	if decodeJSONBody(w, r, &input) != nil {
		handler.writeError(w, r, scheduling.ErrInvalidSchedule)
		return
	}
	identity, _ := authenticatedIdentity(r.Context())
	block, err := handler.manager.AddBlock(r.Context(), identity.UID, ports.ScheduleBlockInput{StartsAt: input.StartsAt, EndsAt: input.EndsAt, Reason: input.Reason})
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"data": blockResponse(block)})
}

func (handler *ScheduleHandler) DeleteBlock(w http.ResponseWriter, r *http.Request) {
	identity, _ := authenticatedIdentity(r.Context())
	if err := handler.manager.DeleteBlock(r.Context(), identity.UID, r.PathValue("id")); err != nil {
		handler.writeError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (handler *ScheduleHandler) Slots(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	page, cursor, err := handler.availability.Slots(r.Context(), r.PathValue("id"), ports.AvailabilityInput{From: r.URL.Query().Get("from"), Cursor: r.URL.Query().Get("cursor"), Limit: limit})
	if err != nil {
		handler.writeError(w, r, err)
		return
	}
	slots := make([]string, 0, len(page.Slots))
	for _, slot := range page.Slots {
		slots = append(slots, slot.UTC().Format(time.RFC3339))
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": map[string]any{"slots": slots, "next_cursor": cursor}})
}

func (handler *ScheduleHandler) writeError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, scheduling.ErrInvalidSchedule):
		writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Confira os horários e tente novamente."})
	case errors.Is(err, scheduling.ErrForbidden):
		writeJSON(w, http.StatusForbidden, map[string]string{"message": "A agenda não está disponível para esta conta."})
	case errors.Is(err, scheduling.ErrNotFound):
		writeJSON(w, http.StatusNotFound, map[string]string{"message": "Agenda ou serviço não encontrado."})
	case errors.Is(err, scheduling.ErrVersionConflict):
		writeJSON(w, http.StatusConflict, map[string]string{"message": "A agenda mudou em outro dispositivo. Recarregue e tente novamente."})
	default:
		slog.ErrorContext(r.Context(), "schedule operation failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível acessar a agenda agora."})
	}
}

func scheduleResponse(plan scheduling.Plan) map[string]any {
	rules := make([]map[string]int, 0, len(plan.Rules))
	for _, rule := range plan.Rules {
		rules = append(rules, map[string]int{"weekday": rule.Weekday, "start_minute": rule.StartMinute, "end_minute": rule.EndMinute})
	}
	blocks := make([]map[string]any, 0, len(plan.Blocks))
	for _, block := range plan.Blocks {
		blocks = append(blocks, blockResponse(block))
	}
	return map[string]any{"time_zone": plan.Settings.TimeZone, "minimum_notice_minutes": plan.Settings.MinimumNoticeMinutes, "booking_horizon_days": plan.Settings.BookingHorizonDays, "buffer_minutes": plan.Settings.BufferMinutes, "slot_interval_minutes": plan.Settings.SlotIntervalMinutes, "version": plan.Settings.Version, "rules": rules, "blocks": blocks}
}

func blockResponse(block scheduling.Block) map[string]any {
	return map[string]any{"id": block.ID, "starts_at": block.Start.UTC().Format(time.RFC3339), "ends_at": block.End.UTC().Format(time.RFC3339), "reason": block.Reason}
}
