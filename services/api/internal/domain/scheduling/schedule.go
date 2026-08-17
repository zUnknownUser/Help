package scheduling

import (
	"errors"
	"sort"
	"strings"
	"time"
	"unicode/utf8"
)

var (
	ErrInvalidSchedule = errors.New("invalid provider schedule")
	ErrNotFound        = errors.New("provider schedule not found")
	ErrForbidden       = errors.New("provider schedule forbidden")
	ErrVersionConflict = errors.New("provider schedule version conflict")
	ErrSlotUnavailable = errors.New("service slot unavailable")
)

type Settings struct {
	TimeZone                                                                              string
	MinimumNoticeMinutes, BookingHorizonDays, BufferMinutes, SlotIntervalMinutes, Version int
}

type SettingsInput struct {
	TimeZone                                                                     string
	MinimumNoticeMinutes, BookingHorizonDays, BufferMinutes, SlotIntervalMinutes int
}

type Rule struct{ Weekday, StartMinute, EndMinute int }
type Block struct {
	ID, Reason string
	Start, End time.Time
}
type TimeRange struct{ Start, End time.Time }
type Plan struct {
	Settings Settings
	Rules    []Rule
	Blocks   []Block
}
type Snapshot struct {
	Settings             Settings
	Rules                []Rule
	Blocks, Reservations []TimeRange
	DurationMinutes      int
}
type SlotPage struct {
	Slots      []time.Time
	NextCursor *time.Time
}

func NewPlan(input SettingsInput, rules []Rule) (Plan, error) {
	zone := strings.TrimSpace(input.TimeZone)
	if _, err := time.LoadLocation(zone); err != nil || input.MinimumNoticeMinutes < 15 || input.MinimumNoticeMinutes > 10080 || input.BookingHorizonDays < 1 || input.BookingHorizonDays > 180 || input.BufferMinutes < 0 || input.BufferMinutes > 240 || (input.SlotIntervalMinutes != 15 && input.SlotIntervalMinutes != 30 && input.SlotIntervalMinutes != 60) || len(rules) > 21 {
		return Plan{}, ErrInvalidSchedule
	}
	sorted := append([]Rule(nil), rules...)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].Weekday == sorted[j].Weekday {
			return sorted[i].StartMinute < sorted[j].StartMinute
		}
		return sorted[i].Weekday < sorted[j].Weekday
	})
	for index, rule := range sorted {
		if rule.Weekday < 0 || rule.Weekday > 6 || rule.StartMinute < 0 || rule.EndMinute > 1440 || rule.StartMinute%15 != 0 || rule.EndMinute%15 != 0 || rule.EndMinute-rule.StartMinute < 30 {
			return Plan{}, ErrInvalidSchedule
		}
		if index > 0 && sorted[index-1].Weekday == rule.Weekday && sorted[index-1].EndMinute > rule.StartMinute {
			return Plan{}, ErrInvalidSchedule
		}
	}
	return Plan{Settings: Settings{TimeZone: zone, MinimumNoticeMinutes: input.MinimumNoticeMinutes, BookingHorizonDays: input.BookingHorizonDays, BufferMinutes: input.BufferMinutes, SlotIntervalMinutes: input.SlotIntervalMinutes}, Rules: sorted}, nil
}

func NewBlock(start, end time.Time, reason string) (Block, error) {
	reason = strings.Join(strings.Fields(reason), " ")
	if start.IsZero() || !end.After(start) || end.Sub(start) > 31*24*time.Hour || utf8.RuneCountInString(reason) > 120 {
		return Block{}, ErrInvalidSchedule
	}
	return Block{Start: start.UTC().Truncate(time.Microsecond), End: end.UTC().Truncate(time.Microsecond), Reason: reason}, nil
}

func GenerateSlots(snapshot Snapshot, now, from time.Time, cursor *time.Time, limit int) (SlotPage, error) {
	location, err := time.LoadLocation(snapshot.Settings.TimeZone)
	if err != nil || snapshot.DurationMinutes <= 0 || limit < 1 {
		return SlotPage{}, ErrInvalidSchedule
	}
	lower := now.Add(time.Duration(snapshot.Settings.MinimumNoticeMinutes) * time.Minute)
	if from.After(lower) {
		lower = from
	}
	if cursor != nil && cursor.After(lower) {
		lower = cursor.Add(time.Microsecond)
	}
	until := now.AddDate(0, 0, snapshot.Settings.BookingHorizonDays)
	localStart := lower.In(location)
	day := time.Date(localStart.Year(), localStart.Month(), localStart.Day(), 0, 0, 0, 0, location)
	localEnd := until.In(location)
	endDay := time.Date(localEnd.Year(), localEnd.Month(), localEnd.Day(), 23, 59, 59, 0, location)
	results := make([]time.Time, 0, limit+1)
	reservedDuration := time.Duration(snapshot.DurationMinutes+snapshot.Settings.BufferMinutes) * time.Minute
	for !day.After(endDay) && len(results) <= limit {
		weekday := int(day.Weekday())
		for _, rule := range snapshot.Rules {
			if rule.Weekday != weekday {
				continue
			}
			for minute := rule.StartMinute; minute+snapshot.DurationMinutes <= rule.EndMinute; minute += snapshot.Settings.SlotIntervalMinutes {
				candidate := day.Add(time.Duration(minute) * time.Minute).UTC()
				if candidate.Before(lower) || candidate.After(until) {
					continue
				}
				rangeValue := TimeRange{Start: candidate, End: candidate.Add(reservedDuration)}
				if overlapsAny(rangeValue, snapshot.Blocks) || overlapsAny(rangeValue, snapshot.Reservations) {
					continue
				}
				results = append(results, candidate)
				if len(results) > limit {
					break
				}
			}
		}
		day = day.AddDate(0, 0, 1)
	}
	page := SlotPage{Slots: results}
	if len(results) > limit {
		cursor := results[limit-1]
		page.Slots = results[:limit]
		page.NextCursor = &cursor
	}
	return page, nil
}

func overlapsAny(candidate TimeRange, ranges []TimeRange) bool {
	for _, item := range ranges {
		if candidate.Start.Before(item.End) && item.Start.Before(candidate.End) {
			return true
		}
	}
	return false
}
