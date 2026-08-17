package ports

import (
	"context"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

type HelpNowRepository interface {
	Create(context.Context, string, helpnow.CreateInput, time.Time) (helpnow.Request, error)
	GetActive(context.Context, string) (*helpnow.Request, error)
	Cancel(context.Context, string, string) (helpnow.Request, error)
	GetAvailability(context.Context, string, time.Time) (helpnow.Availability, error)
	SetAvailability(context.Context, string, helpnow.Availability, time.Time) (helpnow.Availability, error)
	ListOffers(context.Context, string, time.Time) ([]helpnow.Offer, error)
	Respond(context.Context, string, helpnow.Command, time.Time) (helpnow.Request, []string, error)
	DispatchDue(context.Context, time.Time, int) ([]helpnow.DispatchEvent, error)
}

type HelpNowService interface {
	Create(context.Context, string, HelpNowCreateInput) (helpnow.Request, error)
	Active(context.Context, string) (*helpnow.Request, error)
	Cancel(context.Context, string, string) (helpnow.Request, error)
	Availability(context.Context, string) (helpnow.Availability, error)
	SetAvailability(context.Context, string, HelpNowAvailabilityInput) (helpnow.Availability, error)
	Offers(context.Context, string) ([]helpnow.Offer, error)
	Respond(context.Context, string, HelpNowOfferResponseInput) (helpnow.Request, error)
}

type HelpNowCreateInput struct {
	ClientID, CategoryID, Note, AddressLabel, Address string
	Latitude, Longitude                               float64
}

type HelpNowAvailabilityInput struct {
	Enabled             bool
	Latitude, Longitude float64
	MaxDistanceKM       int
}

type HelpNowOfferResponseInput struct{ ClientCommandID, OfferID, Action string }
