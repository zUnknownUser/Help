package servicerequests

import (
	"errors"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
)

var (
	ErrInvalidClientID     = errors.New("invalid service request client id")
	ErrInvalidSchedule     = errors.New("invalid service request schedule")
	ErrInvalidNote         = errors.New("invalid service request note")
	ErrNotFound            = errors.New("service request not found")
	ErrServiceUnavailable  = errors.New("service unavailable")
	ErrCustomerRequired    = errors.New("customer role required")
	ErrAddressRequired     = errors.New("default customer address required")
	ErrOwnService          = errors.New("cannot request own service")
	ErrIdempotencyConflict = errors.New("service request idempotency conflict")
	ErrForbidden           = errors.New("service request action forbidden")
	ErrInvalidStatus       = errors.New("invalid service request status")
	ErrInvalidTransition   = errors.New("invalid service request transition")
	ErrVersionConflict     = errors.New("service request version conflict")
	ErrSlotUnavailable     = errors.New("service request slot unavailable")
)

type Status string

const (
	StatusPending    Status = "pending"
	StatusAccepted   Status = "accepted"
	StatusRejected   Status = "rejected"
	StatusInProgress Status = "in_progress"
	StatusCompleted  Status = "completed"
	StatusCancelled  Status = "cancelled"
	StatusNoShow     Status = "no_show"
)

type ViewerRole string

const (
	ViewerCustomer ViewerRole = "customer"
	ViewerProvider ViewerRole = "provider"
)

type Draft struct {
	ClientID     string
	ScheduledFor time.Time
	Note         string
}

type Request struct {
	ID, ClientID, ServiceID, ServiceTitle, ProviderID, ProviderUID, ProviderName string
	CustomerUID, CustomerName, Note, AddressLabel, Address, StatusReason         string
	Status                                                                       Status
	ViewerRole                                                                   ViewerRole
	ScheduledFor, ScheduledEnd, CreatedAt, UpdatedAt                             time.Time
	QuotedPriceCents, Version                                                    int
	Latitude, Longitude                                                          float64
}

type Cursor struct {
	UpdatedAt time.Time
	ID        string
}

type Transition struct {
	ClientID        string
	Target          Status
	ExpectedVersion int
	Reason          string
}

type Reschedule struct {
	ClientID        string
	ScheduledFor    time.Time
	ExpectedVersion int
}

func ParseStatus(value string) (Status, error) {
	status := Status(strings.TrimSpace(value))
	switch status {
	case StatusPending, StatusAccepted, StatusRejected, StatusInProgress, StatusCompleted, StatusCancelled, StatusNoShow:
		return status, nil
	default:
		return "", ErrInvalidStatus
	}
}

func NewReschedule(clientID, scheduledFor string, expectedVersion int) (Reschedule, error) {
	if _, err := uuid.Parse(clientID); err != nil || expectedVersion < 0 {
		return Reschedule{}, ErrInvalidTransition
	}
	parsed, err := time.Parse(time.RFC3339, scheduledFor)
	if err != nil {
		return Reschedule{}, ErrInvalidSchedule
	}
	return Reschedule{ClientID: clientID, ScheduledFor: parsed.UTC().Truncate(time.Microsecond), ExpectedVersion: expectedVersion}, nil
}

func ParseViewerRole(value string) (ViewerRole, error) {
	role := ViewerRole(strings.TrimSpace(value))
	if role != ViewerCustomer && role != ViewerProvider {
		return "", ErrForbidden
	}
	return role, nil
}

func NewTransition(clientID, target string, expectedVersion int, reason string) (Transition, error) {
	if _, err := uuid.Parse(clientID); err != nil || expectedVersion < 0 {
		return Transition{}, ErrInvalidTransition
	}
	status, err := ParseStatus(target)
	if err != nil || status == StatusPending {
		return Transition{}, ErrInvalidTransition
	}
	reason = strings.Join(strings.Fields(reason), " ")
	if utf8.RuneCountInString(reason) > 500 {
		return Transition{}, ErrInvalidTransition
	}
	return Transition{ClientID: clientID, Target: status, ExpectedVersion: expectedVersion, Reason: reason}, nil
}

func CanTransition(from, to Status, role ViewerRole) bool {
	if role == ViewerCustomer {
		return to == StatusCancelled && (from == StatusPending || from == StatusAccepted)
	}
	if role != ViewerProvider {
		return false
	}
	switch from {
	case StatusPending:
		return to == StatusAccepted || to == StatusRejected
	case StatusAccepted:
		return to == StatusInProgress || to == StatusCancelled || to == StatusNoShow
	case StatusInProgress:
		return to == StatusCompleted || to == StatusCancelled || to == StatusNoShow
	default:
		return false
	}
}

func AvailableTransitions(status Status, role ViewerRole) []Status {
	candidates := []Status{StatusAccepted, StatusRejected, StatusInProgress, StatusCompleted, StatusCancelled, StatusNoShow}
	available := make([]Status, 0, 2)
	for _, candidate := range candidates {
		if CanTransition(status, candidate, role) {
			available = append(available, candidate)
		}
	}
	return available
}

func AvailableTransitionsFor(request Request, now time.Time) []Status {
	available := AvailableTransitions(request.Status, request.ViewerRole)
	if !now.Before(request.ScheduledFor) {
		return available
	}
	filtered := available[:0]
	for _, status := range available {
		if status != StatusNoShow {
			filtered = append(filtered, status)
		}
	}
	return filtered
}

func NewDraft(clientID string, scheduledFor time.Time, note string) (Draft, error) {
	if _, err := uuid.Parse(clientID); err != nil {
		return Draft{}, ErrInvalidClientID
	}
	if scheduledFor.IsZero() {
		return Draft{}, ErrInvalidSchedule
	}
	note = strings.Join(strings.Fields(note), " ")
	if utf8.RuneCountInString(note) > 1000 {
		return Draft{}, ErrInvalidNote
	}
	return Draft{
		ClientID: clientID, ScheduledFor: scheduledFor.UTC().Truncate(time.Microsecond), Note: note,
	}, nil
}

func (draft Draft) SameIntent(serviceID string, request Request) bool {
	return request.ServiceID == serviceID && request.Note == draft.Note &&
		request.ScheduledFor.Equal(draft.ScheduledFor)
}
