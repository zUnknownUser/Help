package scheduling

import (
	"context"
	"encoding/base64"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domain "github.com/vendlydigital/help/services/api/internal/domain/scheduling"
)

const defaultSlotLimit = 40

type Service struct {
	availability ports.ServiceAvailabilityRepository
	schedules    ports.ProviderScheduleRepository
	now          func() time.Time
}

type AvailabilityInput = ports.AvailabilityInput

func NewService(availability ports.ServiceAvailabilityRepository, schedules ports.ProviderScheduleRepository, now func() time.Time) *Service {
	return &Service{availability: availability, schedules: schedules, now: now}
}

func (service *Service) Get(ctx context.Context, uid string) (domain.Plan, error) {
	return service.schedules.Get(ctx, uid)
}

func (service *Service) Replace(ctx context.Context, uid string, input ports.ProviderScheduleInput) (domain.Plan, error) {
	plan, err := domain.NewPlan(domain.SettingsInput{TimeZone: input.TimeZone, MinimumNoticeMinutes: input.MinimumNoticeMinutes, BookingHorizonDays: input.BookingHorizonDays, BufferMinutes: input.BufferMinutes, SlotIntervalMinutes: input.SlotIntervalMinutes}, input.Rules)
	if err != nil {
		return domain.Plan{}, err
	}
	return service.schedules.Replace(ctx, uid, input.ExpectedVersion, plan)
}

func (service *Service) AddBlock(ctx context.Context, uid string, input ports.ScheduleBlockInput) (domain.Block, error) {
	start, startErr := time.Parse(time.RFC3339, input.StartsAt)
	end, endErr := time.Parse(time.RFC3339, input.EndsAt)
	if startErr != nil || endErr != nil {
		return domain.Block{}, domain.ErrInvalidSchedule
	}
	block, err := domain.NewBlock(start, end, input.Reason)
	if err != nil || block.End.Before(service.now()) {
		return domain.Block{}, domain.ErrInvalidSchedule
	}
	return service.schedules.AddBlock(ctx, uid, block)
}

func (service *Service) DeleteBlock(ctx context.Context, uid, id string) error {
	if _, err := uuid.Parse(id); err != nil {
		return domain.ErrInvalidSchedule
	}
	return service.schedules.DeleteBlock(ctx, uid, id)
}

func (service *Service) Slots(ctx context.Context, serviceID string, input ports.AvailabilityInput) (domain.SlotPage, string, error) {
	now := service.now().UTC()
	from := now
	if strings.TrimSpace(input.From) != "" {
		parsed, err := time.Parse(time.RFC3339, input.From)
		if err != nil {
			return domain.SlotPage{}, "", domain.ErrInvalidSchedule
		}
		from = parsed.UTC()
	}
	var cursor *time.Time
	if input.Cursor != "" {
		parsed, err := decodeCursor(input.Cursor)
		if err != nil {
			return domain.SlotPage{}, "", domain.ErrInvalidSchedule
		}
		cursor = &parsed
	}
	limit := input.Limit
	if limit <= 0 {
		limit = defaultSlotLimit
	}
	if limit > 100 {
		limit = 100
	}
	until := now.AddDate(0, 0, 180)
	snapshot, err := service.availability.Snapshot(ctx, strings.TrimSpace(serviceID), from, until)
	if err != nil {
		return domain.SlotPage{}, "", err
	}
	page, err := domain.GenerateSlots(snapshot, now, from, cursor, limit)
	if err != nil {
		return domain.SlotPage{}, "", err
	}
	next := ""
	if page.NextCursor != nil {
		next = encodeCursor(*page.NextCursor)
	}
	return page, next, nil
}

func encodeCursor(value time.Time) string {
	return base64.RawURLEncoding.EncodeToString([]byte(value.UTC().Format(time.RFC3339Nano)))
}
func decodeCursor(value string) (time.Time, error) {
	raw, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return time.Time{}, err
	}
	return time.Parse(time.RFC3339Nano, string(raw))
}
