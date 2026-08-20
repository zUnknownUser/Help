package ports

import (
	"context"
	"io"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type ServiceRequestNegotiationRepository interface {
	GetNegotiation(context.Context, string, string) (servicerequests.Request, servicerequests.Negotiation, error)
	ProposeQuote(context.Context, string, string, servicerequests.QuoteDraft) (servicerequests.Request, servicerequests.Negotiation, string, error)
	AcceptQuote(context.Context, string, string, string, string, int, time.Time) (servicerequests.Request, servicerequests.Negotiation, string, error)
	CreateAttachment(context.Context, string, string, servicerequests.Attachment) (servicerequests.Attachment, string, error)
	GetAttachment(context.Context, string, string) (servicerequests.Attachment, error)
	DeleteAttachment(context.Context, string, string, string) (string, string, error)
}

type ServiceRequestNegotiationResult struct {
	Request     servicerequests.Request
	Negotiation servicerequests.Negotiation
}

type ServiceRequestQuoteInput struct {
	ClientCommandID string
	ExpectedVersion int
	Message         string
	ExpiresAt       string
	Items           []servicerequests.QuoteItemDraft
}

type ServiceRequestQuoteAcceptInput struct {
	ClientCommandID string
	ExpectedVersion int
}

type ServiceRequestNegotiationService interface {
	Get(context.Context, string, string) (ServiceRequestNegotiationResult, error)
	Propose(context.Context, string, string, ServiceRequestQuoteInput) (ServiceRequestNegotiationResult, error)
	Accept(context.Context, string, string, string, ServiceRequestQuoteAcceptInput) (ServiceRequestNegotiationResult, error)
	UploadAttachment(context.Context, string, string, string, string, io.Reader) (servicerequests.Attachment, error)
	OpenAttachment(context.Context, string, string) (servicerequests.Attachment, MediaObject, error)
	DeleteAttachment(context.Context, string, string, string) error
}

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
