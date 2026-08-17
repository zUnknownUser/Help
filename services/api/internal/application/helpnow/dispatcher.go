package helpnow

import (
	"context"
	"log/slog"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type Dispatcher struct {
	repository ports.HelpNowRepository
	realtime   ports.RealtimePublisher
	interval   time.Duration
	now        func() time.Time
}

func NewDispatcher(repository ports.HelpNowRepository, realtime ports.RealtimePublisher, interval time.Duration, now func() time.Time) *Dispatcher {
	return &Dispatcher{repository: repository, realtime: realtime, interval: interval, now: now}
}

func (dispatcher *Dispatcher) Run(ctx context.Context) {
	ticker := time.NewTicker(dispatcher.interval)
	defer ticker.Stop()
	for {
		dispatcher.dispatch(ctx)
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

func (dispatcher *Dispatcher) dispatch(ctx context.Context) {
	events, err := dispatcher.repository.DispatchDue(ctx, dispatcher.now(), 25)
	if err != nil {
		slog.WarnContext(ctx, "help now dispatch failed", "error", err)
		return
	}
	for _, event := range events {
		dispatcher.realtime.Publish(event.UserID, ports.RealtimeEvent{Type: event.Type, Data: map[string]string{
			"request_id": event.RequestID, "offer_id": event.OfferID,
		}})
	}
}
