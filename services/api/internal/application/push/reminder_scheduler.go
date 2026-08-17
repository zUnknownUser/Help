package push

import (
	"context"
	"log/slog"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type ReminderScheduler struct {
	repository ports.ServiceRequestReminderRepository
	interval   time.Duration
	now        func() time.Time
}

func NewReminderScheduler(repository ports.ServiceRequestReminderRepository, interval time.Duration, now func() time.Time) *ReminderScheduler {
	return &ReminderScheduler{repository: repository, interval: interval, now: now}
}

func (scheduler *ReminderScheduler) Run(ctx context.Context) {
	scheduler.enqueue(ctx)
	ticker := time.NewTicker(scheduler.interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			scheduler.enqueue(ctx)
		}
	}
}

func (scheduler *ReminderScheduler) enqueue(ctx context.Context) {
	count, err := scheduler.repository.EnqueueDueReminders(ctx, scheduler.now().UTC(), 200)
	if err != nil {
		slog.ErrorContext(ctx, "service request reminder scheduling failed", "error", err)
		return
	}
	if count > 0 {
		slog.InfoContext(ctx, "service request reminders queued", "count", count)
	}
}
