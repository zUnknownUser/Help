package servicerequests

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"strings"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

const (
	defaultPageSize = 20
	maximumPageSize = 50
)

type Lifecycle struct {
	repository ports.ServiceRequestLifecycleRepository
	now        func() time.Time
}

func NewLifecycle(repository ports.ServiceRequestLifecycleRepository, clock ...func() time.Time) *Lifecycle {
	now := time.Now
	if len(clock) > 0 && clock[0] != nil {
		now = clock[0]
	}
	return &Lifecycle{repository: repository, now: now}
}

func (lifecycle *Lifecycle) List(
	ctx context.Context,
	uid string,
	input ports.ServiceRequestListInput,
) (ports.ServiceRequestPage, error) {
	role, err := domainrequests.ParseViewerRole(input.Role)
	if err != nil {
		return ports.ServiceRequestPage{}, err
	}
	cursor, err := decodeCursor(input.Cursor)
	if err != nil {
		return ports.ServiceRequestPage{}, domainrequests.ErrInvalidTransition
	}
	limit := input.Limit
	if limit <= 0 {
		limit = defaultPageSize
	}
	if limit > maximumPageSize {
		limit = maximumPageSize
	}
	items, err := lifecycle.repository.List(ctx, uid, role, cursor, limit+1)
	if err != nil {
		return ports.ServiceRequestPage{}, err
	}
	page := ports.ServiceRequestPage{Items: items}
	if len(items) > limit {
		page.Items = items[:limit]
		last := page.Items[len(page.Items)-1]
		page.NextCursor = encodeCursor(domainrequests.Cursor{UpdatedAt: last.UpdatedAt, ID: last.ID})
	}
	return page, nil
}

func (lifecycle *Lifecycle) Get(ctx context.Context, uid, requestID string) (domainrequests.Request, error) {
	return lifecycle.repository.Get(ctx, uid, strings.TrimSpace(requestID))
}

func (lifecycle *Lifecycle) Transition(
	ctx context.Context,
	uid, requestID string,
	input ports.ServiceRequestTransitionInput,
) (domainrequests.Request, error) {
	transition, err := domainrequests.NewTransition(
		input.ClientCommandID, input.TargetStatus, input.ExpectedVersion, input.Reason,
	)
	if err != nil {
		return domainrequests.Request{}, err
	}
	return lifecycle.repository.Transition(ctx, uid, strings.TrimSpace(requestID), transition)
}

func (lifecycle *Lifecycle) Reschedule(
	ctx context.Context,
	uid, requestID string,
	input ports.ServiceRequestRescheduleInput,
) (domainrequests.Request, error) {
	command, err := domainrequests.NewReschedule(input.ClientCommandID, input.ScheduledFor, input.ExpectedVersion)
	if err != nil {
		return domainrequests.Request{}, err
	}
	now := lifecycle.now()
	if command.ScheduledFor.Before(now.Add(minimumLeadTime)) || command.ScheduledFor.After(now.Add(maximumLeadTime)) {
		return domainrequests.Request{}, domainrequests.ErrInvalidSchedule
	}
	return lifecycle.repository.Reschedule(ctx, uid, strings.TrimSpace(requestID), command)
}

func (lifecycle *Lifecycle) Agenda(ctx context.Context, uid string, input ports.ServiceRequestAgendaInput) ([]domainrequests.Request, error) {
	from, fromErr := time.Parse(time.RFC3339, input.From)
	to, toErr := time.Parse(time.RFC3339, input.To)
	if fromErr != nil || toErr != nil || !to.After(from) || to.Sub(from) > 31*24*time.Hour {
		return nil, domainrequests.ErrInvalidSchedule
	}
	limit := input.Limit
	if limit <= 0 {
		limit = 200
	}
	if limit > 500 {
		limit = 500
	}
	return lifecycle.repository.Agenda(ctx, uid, from.UTC(), to.UTC(), limit)
}

type wireCursor struct {
	UpdatedAt string `json:"updated_at"`
	ID        string `json:"id"`
}

func encodeCursor(cursor domainrequests.Cursor) string {
	payload, _ := json.Marshal(wireCursor{UpdatedAt: cursor.UpdatedAt.UTC().Format(time.RFC3339Nano), ID: cursor.ID})
	return base64.RawURLEncoding.EncodeToString(payload)
}

func decodeCursor(value string) (*domainrequests.Cursor, error) {
	if strings.TrimSpace(value) == "" {
		return nil, nil
	}
	payload, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return nil, err
	}
	var cursor wireCursor
	if err := json.Unmarshal(payload, &cursor); err != nil || cursor.ID == "" {
		return nil, domainrequests.ErrInvalidTransition
	}
	updatedAt, err := time.Parse(time.RFC3339Nano, cursor.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &domainrequests.Cursor{UpdatedAt: updatedAt, ID: cursor.ID}, nil
}
