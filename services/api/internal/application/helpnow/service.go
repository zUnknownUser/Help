package helpnow

import (
	"context"
	"log/slog"
	"strings"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

type Service struct {
	repository ports.HelpNowRepository
	realtime   ports.RealtimePublisher
	now        func() time.Time
}

func NewService(repository ports.HelpNowRepository, realtime ports.RealtimePublisher, now func() time.Time) *Service {
	return &Service{repository: repository, realtime: realtime, now: now}
}

func (service *Service) Create(ctx context.Context, uid string, raw ports.HelpNowCreateInput) (domainhelp.Request, error) {
	input, err := domainhelp.NewCreateInput(raw.ClientID, raw.CategoryID, raw.Note,
		raw.AddressLabel, raw.Address, raw.Latitude, raw.Longitude)
	if err != nil {
		return domainhelp.Request{}, err
	}
	request, err := service.repository.Create(ctx, uid, input, service.now())
	if err == nil {
		slog.InfoContext(ctx, "help now search created", "user_id", uid, "request_id", request.ID, "category_id", request.CategoryID)
	}
	return request, err
}

func (service *Service) Active(ctx context.Context, uid string) (*domainhelp.Request, error) {
	return service.repository.GetActive(ctx, uid)
}

func (service *Service) Cancel(ctx context.Context, uid, requestID string) (domainhelp.Request, error) {
	request, err := service.repository.Cancel(ctx, uid, strings.TrimSpace(requestID))
	if err == nil {
		slog.InfoContext(ctx, "help now search cancelled", "user_id", uid, "request_id", request.ID)
	}
	return request, err
}

func (service *Service) Availability(ctx context.Context, uid string) (domainhelp.Availability, error) {
	return service.repository.GetAvailability(ctx, uid, service.now())
}

func (service *Service) SetAvailability(ctx context.Context, uid string, raw ports.HelpNowAvailabilityInput) (domainhelp.Availability, error) {
	input, err := domainhelp.NewAvailability(raw.Enabled, raw.Latitude, raw.Longitude, raw.MaxDistanceKM)
	if err != nil {
		return domainhelp.Availability{}, err
	}
	availability, err := service.repository.SetAvailability(ctx, uid, input, service.now())
	if err == nil {
		slog.InfoContext(ctx, "help now provider availability changed", "user_id", uid, "enabled", availability.Enabled)
	}
	return availability, err
}

func (service *Service) Offers(ctx context.Context, uid string) ([]domainhelp.Offer, error) {
	return service.repository.ListOffers(ctx, uid, service.now())
}

func (service *Service) Respond(ctx context.Context, uid string, raw ports.HelpNowOfferResponseInput) (domainhelp.Request, error) {
	command, err := domainhelp.NewCommand(raw.ClientCommandID, raw.OfferID, raw.Action)
	if err != nil {
		return domainhelp.Request{}, err
	}
	request, losers, err := service.repository.Respond(ctx, uid, command, service.now())
	if err != nil {
		return domainhelp.Request{}, err
	}
	if command.Action == "accept" {
		service.realtime.Publish(request.CustomerID, ports.RealtimeEvent{Type: "help_now.updated", Data: map[string]string{"request_id": request.ID}})
		for _, userID := range losers {
			service.realtime.Publish(userID, ports.RealtimeEvent{Type: "help_now.offer_closed", Data: map[string]string{"request_id": request.ID}})
		}
	}
	slog.InfoContext(ctx, "help now offer answered", "user_id", uid, "request_id", request.ID, "action", command.Action)
	return request, nil
}
