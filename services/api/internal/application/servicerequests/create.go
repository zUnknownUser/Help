package servicerequests

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

const (
	minimumLeadTime = 15 * time.Minute
	maximumLeadTime = 180 * 24 * time.Hour
)

type Creator struct {
	repository ports.ServiceRequestRepository
	now        func() time.Time
}

func NewCreator(repository ports.ServiceRequestRepository, now func() time.Time) *Creator {
	return &Creator{repository: repository, now: now}
}

func (creator *Creator) Execute(
	ctx context.Context,
	uid, serviceID string,
	input ports.ServiceRequestInput,
) (domainrequests.Request, error) {
	scheduledFor, err := time.Parse(time.RFC3339, input.ScheduledFor)
	if err != nil {
		return domainrequests.Request{}, domainrequests.ErrInvalidSchedule
	}
	draft, err := domainrequests.NewDraft(input.ClientID, scheduledFor, input.Note)
	if err != nil {
		return domainrequests.Request{}, err
	}
	serviceID = strings.TrimSpace(serviceID)
	existing, err := creator.repository.FindByClientID(ctx, uid, draft.ClientID)
	if err == nil {
		if !draft.SameIntent(serviceID, existing) {
			return domainrequests.Request{}, domainrequests.ErrIdempotencyConflict
		}
		return existing, nil
	}
	if !errors.Is(err, domainrequests.ErrNotFound) {
		return domainrequests.Request{}, err
	}
	now := creator.now()
	if scheduledFor.Before(now.Add(minimumLeadTime)) || scheduledFor.After(now.Add(maximumLeadTime)) {
		return domainrequests.Request{}, domainrequests.ErrInvalidSchedule
	}
	return creator.repository.Create(ctx, uid, serviceID, draft)
}
