package push

import (
	"context"
	"log/slog"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type Dispatcher struct {
	devices ports.DeviceRepository
	outbox  ports.PushOutboxRepository
	sender  ports.PushSender
}

func NewDispatcher(devices ports.DeviceRepository, outbox ports.PushOutboxRepository, sender ports.PushSender) *Dispatcher {
	return &Dispatcher{devices: devices, outbox: outbox, sender: sender}
}

func (dispatcher *Dispatcher) Run(ctx context.Context) {
	ticker := time.NewTicker(time.Second)
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
	deliveries, err := dispatcher.outbox.Claim(ctx, 50)
	if err != nil {
		slog.WarnContext(ctx, "claim push notifications failed", "error", err)
		return
	}
	for _, delivery := range deliveries {
		dispatcher.deliver(ctx, delivery)
	}
}

func (dispatcher *Dispatcher) deliver(ctx context.Context, delivery ports.PushDelivery) {
	tokens, err := dispatcher.devices.Tokens(ctx, delivery.UserID)
	if err == nil && len(tokens) > 0 {
		var invalid []string
		invalid, err = dispatcher.sender.Send(ctx, tokens, delivery.Message)
		if disableErr := dispatcher.devices.DisableTokens(ctx, invalid); disableErr != nil && err == nil {
			err = disableErr
		}
	}
	if err == nil {
		if markErr := dispatcher.outbox.MarkDelivered(ctx, delivery.NotificationID); markErr != nil {
			slog.WarnContext(ctx, "mark push delivered failed", "notification_id", delivery.NotificationID, "error", markErr)
		}
		return
	}
	delay := time.Duration(1<<min(delivery.Attempts, 8)) * time.Second
	if retryErr := dispatcher.outbox.Reschedule(ctx, delivery.NotificationID, time.Now().Add(delay), err.Error()); retryErr != nil {
		slog.WarnContext(ctx, "reschedule push failed", "notification_id", delivery.NotificationID, "error", retryErr)
	}
}
