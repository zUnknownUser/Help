package scheduling

import (
	"testing"
	"time"
)

func TestNewPlanRejectsOverlappingRules(t *testing.T) {
	_, err := NewPlan(SettingsInput{TimeZone: "America/Manaus", MinimumNoticeMinutes: 60, BookingHorizonDays: 30, BufferMinutes: 15, SlotIntervalMinutes: 30}, []Rule{
		{Weekday: 1, StartMinute: 480, EndMinute: 720},
		{Weekday: 1, StartMinute: 600, EndMinute: 900},
	})
	if err != ErrInvalidSchedule {
		t.Fatalf("got %v", err)
	}
}

func TestGenerateSlotsHonorsRulesBlocksReservationsAndCursor(t *testing.T) {
	location, _ := time.LoadLocation("America/Manaus")
	now := time.Date(2026, 8, 17, 8, 0, 0, 0, location).UTC() // Monday
	snapshot := Snapshot{
		Settings:        Settings{TimeZone: "America/Manaus", MinimumNoticeMinutes: 60, BookingHorizonDays: 2, BufferMinutes: 15, SlotIntervalMinutes: 30},
		Rules:           []Rule{{Weekday: 1, StartMinute: 540, EndMinute: 720}},
		DurationMinutes: 60,
		Blocks:          []TimeRange{{Start: time.Date(2026, 8, 17, 10, 30, 0, 0, location).UTC(), End: time.Date(2026, 8, 17, 11, 0, 0, 0, location).UTC()}},
		Reservations:    []TimeRange{{Start: time.Date(2026, 8, 17, 10, 15, 0, 0, location).UTC(), End: time.Date(2026, 8, 17, 10, 45, 0, 0, location).UTC()}},
	}
	page, err := GenerateSlots(snapshot, now, time.Date(2026, 8, 17, 8, 0, 0, 0, location).UTC(), nil, 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(page.Slots) != 2 {
		t.Fatalf("slots=%v", page.Slots)
	}
	if got := page.Slots[0].In(location).Format("15:04"); got != "09:00" {
		t.Fatalf("first=%s", got)
	}
	if got := page.Slots[1].In(location).Format("15:04"); got != "11:00" {
		t.Fatalf("last=%s", got)
	}
}

func TestGenerateSlotsReturnsDeterministicCursorPage(t *testing.T) {
	location, _ := time.LoadLocation("America/Manaus")
	now := time.Date(2026, 8, 17, 7, 0, 0, 0, location).UTC()
	snapshot := Snapshot{Settings: Settings{TimeZone: "America/Manaus", MinimumNoticeMinutes: 15, BookingHorizonDays: 1, SlotIntervalMinutes: 30}, Rules: []Rule{{Weekday: 1, StartMinute: 480, EndMinute: 660}}, DurationMinutes: 60}
	page, err := GenerateSlots(snapshot, now, now, nil, 2)
	if err != nil {
		t.Fatal(err)
	}
	if len(page.Slots) != 2 || page.NextCursor == nil {
		t.Fatalf("page=%+v", page)
	}
	next, err := GenerateSlots(snapshot, now, now, page.NextCursor, 2)
	if err != nil {
		t.Fatal(err)
	}
	if len(next.Slots) == 0 || !next.Slots[0].After(page.Slots[1]) {
		t.Fatalf("next=%+v", next)
	}
}
