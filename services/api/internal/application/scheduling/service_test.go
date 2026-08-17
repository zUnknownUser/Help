package scheduling

import (
	"context"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/scheduling"
)

type availabilityStub struct {
	snapshot    scheduling.Snapshot
	from, until time.Time
}

func (stub *availabilityStub) Snapshot(_ context.Context, _ string, from, until time.Time) (scheduling.Snapshot, error) {
	stub.from, stub.until = from, until
	return stub.snapshot, nil
}

func TestSlotsUsesOpaqueCursorAndBoundedLimit(t *testing.T) {
	location, _ := time.LoadLocation("America/Manaus")
	now := time.Date(2026, 8, 17, 7, 0, 0, 0, location).UTC()
	repository := &availabilityStub{snapshot: scheduling.Snapshot{Settings: scheduling.Settings{TimeZone: "America/Manaus", MinimumNoticeMinutes: 15, BookingHorizonDays: 2, SlotIntervalMinutes: 30}, Rules: []scheduling.Rule{{Weekday: 1, StartMinute: 480, EndMinute: 720}}, DurationMinutes: 60}}
	service := NewService(repository, nil, func() time.Time { return now })
	first, cursor, err := service.Slots(context.Background(), "service", AvailabilityInput{Limit: 2})
	if err != nil || len(first.Slots) != 2 || cursor == "" {
		t.Fatalf("page=%+v cursor=%q err=%v", first, cursor, err)
	}
	second, _, err := service.Slots(context.Background(), "service", AvailabilityInput{Limit: 2, Cursor: cursor})
	if err != nil || len(second.Slots) == 0 || !second.Slots[0].After(first.Slots[1]) {
		t.Fatalf("second=%+v err=%v", second, err)
	}
}
