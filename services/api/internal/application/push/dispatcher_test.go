package push

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/devices"
)

type outboxStub struct {
	deliveries  []ports.PushDelivery
	deliveredID string
	retriedID   string
}

func (stub *outboxStub) Claim(context.Context, int) ([]ports.PushDelivery, error) {
	return stub.deliveries, nil
}
func (stub *outboxStub) MarkDelivered(_ context.Context, id string) error {
	stub.deliveredID = id
	return nil
}
func (stub *outboxStub) Reschedule(_ context.Context, id string, _ time.Time, _ string) error {
	stub.retriedID = id
	return nil
}

type deviceStub struct{ disabled []string }

func (stub *deviceStub) Upsert(context.Context, devices.Installation) error { return nil }
func (stub *deviceStub) Disable(context.Context, string, string) error      { return nil }
func (stub *deviceStub) Tokens(context.Context, string) ([]string, error) {
	return []string{"valid", "expired"}, nil
}
func (stub *deviceStub) DisableTokens(_ context.Context, tokens []string) error {
	stub.disabled = tokens
	return nil
}

type senderStub struct{ err error }

func (stub senderStub) Send(context.Context, []string, ports.PushNotification) ([]string, error) {
	return []string{"expired"}, stub.err
}

func TestDispatcherMarksSuccessAndDisablesInvalidTokens(t *testing.T) {
	t.Parallel()
	outbox := &outboxStub{deliveries: []ports.PushDelivery{{NotificationID: "notification-1", UserID: "user-1"}}}
	devices := &deviceStub{}
	NewDispatcher(devices, outbox, senderStub{}).dispatch(context.Background())
	if outbox.deliveredID != "notification-1" || len(devices.disabled) != 1 || devices.disabled[0] != "expired" {
		t.Fatalf("outbox = %+v devices = %+v", outbox, devices)
	}
}

func TestDispatcherReschedulesTransientFailure(t *testing.T) {
	t.Parallel()
	outbox := &outboxStub{deliveries: []ports.PushDelivery{{NotificationID: "notification-2", UserID: "user-1", Attempts: 2}}}
	NewDispatcher(&deviceStub{}, outbox, senderStub{err: errors.New("temporary")}).dispatch(context.Background())
	if outbox.retriedID != "notification-2" || outbox.deliveredID != "" {
		t.Fatalf("outbox = %+v", outbox)
	}
}
