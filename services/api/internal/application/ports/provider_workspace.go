package ports

import (
	"context"

	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type ProviderWorkspaceReader interface {
	GetOverview(ctx context.Context, uid string) (providers.WorkspaceOverview, error)
	ListServices(ctx context.Context, uid string) ([]catalog.Service, error)
	ListRecentRequests(ctx context.Context, uid string, limit int) ([]providers.ServiceRequest, error)
	ListNotifications(ctx context.Context, uid string, limit int) ([]providers.WorkspaceNotification, error)
}

type ActiveCategoryReader interface {
	ListActive(ctx context.Context) ([]categories.Category, error)
}

type ProviderServiceInput struct {
	Title           string
	Description     string
	CategoryID      string
	DurationMinutes int
	PriceCents      int
	ImageURL        string
	Published       bool
}

type ProviderServiceWriter interface {
	CreateService(ctx context.Context, uid string, draft catalog.ServiceDraft) (catalog.Service, error)
	UpdateService(ctx context.Context, uid, serviceID string, draft catalog.ServiceDraft) (catalog.Service, error)
	SetServicePublished(ctx context.Context, uid, serviceID string, published bool) (catalog.Service, error)
	DeleteService(ctx context.Context, uid, serviceID string) error
	SetAcceptingRequests(ctx context.Context, uid string, accepting bool) error
}

type ProviderHomeGetter interface {
	Execute(ctx context.Context, uid string) (providers.Workspace, error)
}

type ProviderServiceManager interface {
	Create(ctx context.Context, uid string, input ProviderServiceInput) (catalog.Service, error)
	Update(ctx context.Context, uid, serviceID string, input ProviderServiceInput) (catalog.Service, error)
	SetPublished(ctx context.Context, uid, serviceID string, published bool) (catalog.Service, error)
	Delete(ctx context.Context, uid, serviceID string) error
	SetAcceptingRequests(ctx context.Context, uid string, accepting bool) error
}
