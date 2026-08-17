package ports

import (
	"context"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/scheduling"
)

type ProviderScheduleRepository interface {
	Get(context.Context, string) (scheduling.Plan, error)
	Replace(context.Context, string, int, scheduling.Plan) (scheduling.Plan, error)
	AddBlock(context.Context, string, scheduling.Block) (scheduling.Block, error)
	DeleteBlock(context.Context, string, string) error
}

type ServiceAvailabilityRepository interface {
	Snapshot(context.Context, string, time.Time, time.Time) (scheduling.Snapshot, error)
}

type ProviderScheduleManager interface {
	Get(context.Context, string) (scheduling.Plan, error)
	Replace(context.Context, string, ProviderScheduleInput) (scheduling.Plan, error)
	AddBlock(context.Context, string, ScheduleBlockInput) (scheduling.Block, error)
	DeleteBlock(context.Context, string, string) error
}

type ServiceAvailability interface {
	Slots(context.Context, string, AvailabilityInput) (scheduling.SlotPage, string, error)
}

type ProviderScheduleInput struct {
	ExpectedVersion                                                              int
	TimeZone                                                                     string
	MinimumNoticeMinutes, BookingHorizonDays, BufferMinutes, SlotIntervalMinutes int
	Rules                                                                        []scheduling.Rule
}

type ScheduleBlockInput struct{ StartsAt, EndsAt, Reason string }
type AvailabilityInput struct {
	From, Cursor string
	Limit        int
}
