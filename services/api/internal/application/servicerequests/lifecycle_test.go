package servicerequests_test

import (
	"context"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	applicationrequests "github.com/vendlydigital/help/services/api/internal/application/servicerequests"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type lifecycleRepositoryStub struct {
	values     []domainrequests.Request
	reschedule domainrequests.Reschedule
}

func (stub *lifecycleRepositoryStub) List(_ context.Context, _ string, role domainrequests.ViewerRole, _ *domainrequests.Cursor, _ int) ([]domainrequests.Request, error) {
	for index := range stub.values {
		stub.values[index].ViewerRole = role
	}
	return stub.values, nil
}
func (stub *lifecycleRepositoryStub) Get(context.Context, string, string) (domainrequests.Request, error) {
	return domainrequests.Request{}, nil
}
func (stub *lifecycleRepositoryStub) Transition(context.Context, string, string, domainrequests.Transition) (domainrequests.Request, error) {
	return domainrequests.Request{}, nil
}

func (stub *lifecycleRepositoryStub) Reschedule(_ context.Context, _, _ string, command domainrequests.Reschedule) (domainrequests.Request, error) {
	stub.reschedule = command
	return domainrequests.Request{}, nil
}
func (stub *lifecycleRepositoryStub) Agenda(context.Context, string, time.Time, time.Time, int) ([]domainrequests.Request, error) {
	return nil, nil
}

func TestLifecyclePaginatesWithOpaqueCursor(t *testing.T) {
	t.Parallel()
	items := make([]domainrequests.Request, 3)
	for index := range items {
		items[index] = domainrequests.Request{ID: string(rune('a' + index)), UpdatedAt: time.Date(2026, 8, 16, 12-index, 0, 0, 0, time.UTC)}
	}
	lifecycle := applicationrequests.NewLifecycle(&lifecycleRepositoryStub{values: items})
	page, err := lifecycle.List(context.Background(), "user", ports.ServiceRequestListInput{Role: "customer", Limit: 2})
	if err != nil || len(page.Items) != 2 || page.NextCursor == "" || page.Items[0].ViewerRole != domainrequests.ViewerCustomer {
		t.Fatalf("page = %+v error = %v", page, err)
	}
}

func TestLifecycleRescheduleUsesInjectedClock(t *testing.T) {
	now := time.Date(2026, 8, 16, 12, 0, 0, 0, time.UTC)
	repository := &lifecycleRepositoryStub{}
	lifecycle := applicationrequests.NewLifecycle(repository, func() time.Time { return now })
	scheduled := now.Add(2 * time.Hour)
	_, err := lifecycle.Reschedule(context.Background(), "user", "request", ports.ServiceRequestRescheduleInput{ClientCommandID: "c349a83e-fbd9-4d59-984d-0516b7f981b2", ScheduledFor: scheduled.Format(time.RFC3339), ExpectedVersion: 2})
	if err != nil || !repository.reschedule.ScheduledFor.Equal(scheduled) || repository.reschedule.ExpectedVersion != 2 {
		t.Fatalf("command=%+v error=%v", repository.reschedule, err)
	}
}

func TestLifecycleRejectsUnboundedAgendaRange(t *testing.T) {
	lifecycle := applicationrequests.NewLifecycle(&lifecycleRepositoryStub{})
	_, err := lifecycle.Agenda(context.Background(), "user", ports.ServiceRequestAgendaInput{From: "2026-08-01T00:00:00Z", To: "2026-10-01T00:00:00Z"})
	if err != domainrequests.ErrInvalidSchedule {
		t.Fatalf("error=%v", err)
	}
}
