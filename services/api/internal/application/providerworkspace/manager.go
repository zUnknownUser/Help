package providerworkspace

import (
	"context"
	"strings"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type Manager struct{ writer ports.ProviderServiceWriter }

func NewManager(writer ports.ProviderServiceWriter) *Manager { return &Manager{writer: writer} }

func (manager *Manager) Create(ctx context.Context, uid string, input ports.ProviderServiceInput) (catalog.Service, error) {
	draft, err := draftFrom(input)
	if err != nil {
		return catalog.Service{}, err
	}
	return manager.writer.CreateService(ctx, uid, draft)
}

func (manager *Manager) Update(ctx context.Context, uid, serviceID string, input ports.ProviderServiceInput) (catalog.Service, error) {
	if strings.TrimSpace(serviceID) == "" {
		return catalog.Service{}, providers.ErrServiceNotFound
	}
	draft, err := draftFrom(input)
	if err != nil {
		return catalog.Service{}, err
	}
	return manager.writer.UpdateService(ctx, uid, serviceID, draft)
}

func (manager *Manager) SetPublished(ctx context.Context, uid, serviceID string, published bool) (catalog.Service, error) {
	if strings.TrimSpace(serviceID) == "" {
		return catalog.Service{}, providers.ErrServiceNotFound
	}
	return manager.writer.SetServicePublished(ctx, uid, serviceID, published)
}

func (manager *Manager) Delete(ctx context.Context, uid, serviceID string) error {
	if strings.TrimSpace(serviceID) == "" {
		return providers.ErrServiceNotFound
	}
	return manager.writer.DeleteService(ctx, uid, serviceID)
}

func (manager *Manager) SetAcceptingRequests(ctx context.Context, uid string, accepting bool) error {
	return manager.writer.SetAcceptingRequests(ctx, uid, accepting)
}

func draftFrom(input ports.ProviderServiceInput) (catalog.ServiceDraft, error) {
	return catalog.NewServiceDraft(
		input.Title, input.Description, input.CategoryID, input.DurationMinutes,
		input.PriceCents, input.OldPriceCents, input.ImageURL, input.Published,
	)
}
