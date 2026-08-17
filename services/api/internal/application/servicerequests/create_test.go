package servicerequests_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	applicationrequests "github.com/vendlydigital/help/services/api/internal/application/servicerequests"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type requestRepositorySpy struct {
	existing domainrequests.Request
	created  domainrequests.Draft
}

func (spy *requestRepositorySpy) FindByClientID(context.Context, string, string) (domainrequests.Request, error) {
	if spy.existing.ID == "" {
		return domainrequests.Request{}, domainrequests.ErrNotFound
	}
	return spy.existing, nil
}
func (spy *requestRepositorySpy) Create(_ context.Context, _, _ string, draft domainrequests.Draft) (domainrequests.Request, error) {
	spy.created = draft
	return domainrequests.Request{ID: "request-1", ServiceID: "service-1", ClientID: draft.ClientID, ScheduledFor: draft.ScheduledFor, Note: draft.Note}, nil
}

func TestCreateValidatesScheduleAndPersists(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, 8, 16, 12, 0, 0, 0, time.UTC)
	repository := &requestRepositorySpy{}
	creator := applicationrequests.NewCreator(repository, func() time.Time { return now })
	request, err := creator.Execute(context.Background(), "customer-1", "service-1", ports.ServiceRequestInput{
		ClientID: "c349a83e-fbd9-4d59-984d-0516b7f981b2", ScheduledFor: now.Add(time.Hour).Format(time.RFC3339), Note: " Ajuda ",
	})
	if err != nil || request.ID != "request-1" || repository.created.Note != "Ajuda" {
		t.Fatalf("request = %+v, draft = %+v, error = %v", request, repository.created, err)
	}
}

func TestCreateReturnsIdempotentRequestBeforeRevalidatingPastSchedule(t *testing.T) {
	t.Parallel()
	scheduled := time.Date(2026, 8, 16, 12, 0, 0, 0, time.UTC)
	existing := domainrequests.Request{ID: "request-1", ServiceID: "service-1", ClientID: "c349a83e-fbd9-4d59-984d-0516b7f981b2", ScheduledFor: scheduled, Note: "Ajuda"}
	repository := &requestRepositorySpy{existing: existing}
	creator := applicationrequests.NewCreator(repository, func() time.Time { return scheduled.Add(24 * time.Hour) })
	request, err := creator.Execute(context.Background(), "customer-1", "service-1", ports.ServiceRequestInput{
		ClientID: existing.ClientID, ScheduledFor: scheduled.Format(time.RFC3339), Note: "Ajuda",
	})
	if err != nil || request.ID != existing.ID || !repository.created.ScheduledFor.IsZero() {
		t.Fatalf("request = %+v, created = %+v, error = %v", request, repository.created, err)
	}
}

func TestCreateRejectsInvalidWindowAndIdempotencyReuse(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, 8, 16, 12, 0, 0, 0, time.UTC)
	for _, scheduled := range []time.Time{now.Add(14 * time.Minute), now.Add(181 * 24 * time.Hour)} {
		creator := applicationrequests.NewCreator(&requestRepositorySpy{}, func() time.Time { return now })
		_, err := creator.Execute(context.Background(), "customer-1", "service-1", ports.ServiceRequestInput{
			ClientID: "c349a83e-fbd9-4d59-984d-0516b7f981b2", ScheduledFor: scheduled.Format(time.RFC3339),
		})
		if !errors.Is(err, domainrequests.ErrInvalidSchedule) {
			t.Fatalf("schedule %s error = %v", scheduled, err)
		}
	}
	existing := domainrequests.Request{ID: "request-1", ServiceID: "other", ClientID: "c349a83e-fbd9-4d59-984d-0516b7f981b2", ScheduledFor: now.Add(time.Hour)}
	creator := applicationrequests.NewCreator(&requestRepositorySpy{existing: existing}, func() time.Time { return now })
	_, err := creator.Execute(context.Background(), "customer-1", "service-1", ports.ServiceRequestInput{
		ClientID: existing.ClientID, ScheduledFor: existing.ScheduledFor.Format(time.RFC3339),
	})
	if !errors.Is(err, domainrequests.ErrIdempotencyConflict) {
		t.Fatalf("error = %v", err)
	}
}
