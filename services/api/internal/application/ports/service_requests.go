package ports

import (
	"context"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type ServiceRequestRepository interface {
	FindByClientID(context.Context, string, string) (servicerequests.Request, error)
	Create(context.Context, string, string, servicerequests.Draft) (servicerequests.Request, error)
}

type ServiceRequestLifecycleRepository interface {
	List(context.Context, string, servicerequests.ViewerRole, *servicerequests.Cursor, int) ([]servicerequests.Request, error)
	Get(context.Context, string, string) (servicerequests.Request, error)
	Transition(context.Context, string, string, servicerequests.Transition) (servicerequests.Request, error)
	Reschedule(context.Context, string, string, servicerequests.Reschedule) (servicerequests.Request, error)
	Agenda(context.Context, string, time.Time, time.Time, int) ([]servicerequests.Request, error)
}

type ServiceRequestCreator interface {
	Execute(context.Context, string, string, ServiceRequestInput) (servicerequests.Request, error)
}

type ServiceRequestInput struct {
	ClientID, Note string
	ScheduledFor   string
}

type ServiceRequestListInput struct {
	Role   string
	Cursor string
	Limit  int
}

type ServiceRequestPage struct {
	Items      []servicerequests.Request
	NextCursor string
}

type ServiceRequestLifecycle interface {
	List(context.Context, string, ServiceRequestListInput) (ServiceRequestPage, error)
	Get(context.Context, string, string) (servicerequests.Request, error)
	Transition(context.Context, string, string, ServiceRequestTransitionInput) (servicerequests.Request, error)
	Reschedule(context.Context, string, string, ServiceRequestRescheduleInput) (servicerequests.Request, error)
	Agenda(context.Context, string, ServiceRequestAgendaInput) ([]servicerequests.Request, error)
}

type ServiceRequestTransitionInput struct {
	ClientCommandID string
	TargetStatus    string
	ExpectedVersion int
	Reason          string
}

type ServiceRequestRescheduleInput struct {
	ClientCommandID string
	ScheduledFor    string
	ExpectedVersion int
}

type ServiceRequestAgendaInput struct {
	From  string
	To    string
	Limit int
}
