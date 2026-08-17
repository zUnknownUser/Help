package push

import (
	"context"
	"testing"
	"time"
)

type reminderRepositoryStub struct {
	calls int
	at    time.Time
	limit int
}

func (stub *reminderRepositoryStub) EnqueueDueReminders(_ context.Context, at time.Time, limit int) (int, error) {
	stub.calls++
	stub.at, stub.limit = at, limit
	return 2, nil
}

func TestReminderSchedulerEnqueuesWithAuthoritativeClock(t *testing.T) {
	expected := time.Date(2026, 8, 16, 16, 0, 0, 0, time.FixedZone("local", -4*60*60))
	repository := &reminderRepositoryStub{}
	scheduler := NewReminderScheduler(repository, time.Minute, func() time.Time { return expected })
	scheduler.enqueue(context.Background())
	if repository.calls != 1 || repository.limit != 200 || !repository.at.Equal(expected.UTC()) {
		t.Fatalf("repository=%+v", repository)
	}
}
