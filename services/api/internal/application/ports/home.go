package ports

import (
	"context"

	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
	"github.com/vendlydigital/help/services/api/internal/domain/promotions"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type CategoryReader interface {
	ListPopular(ctx context.Context) ([]categories.Category, error)
}

type CatalogReader interface {
	ListRecommended(ctx context.Context) ([]catalog.Service, error)
}

type CatalogSearcher interface {
	Search(context.Context, catalog.Filters) (catalog.Page, error)
}

type PromotionReader interface {
	ListActive(ctx context.Context) ([]promotions.Promotion, error)
}

type ProviderReader interface {
	FindByIDs(ctx context.Context, ids []string) (map[string]providers.Provider, error)
}

type HomeFrameReader interface {
	GetFrame(ctx context.Context) (domainhome.Frame, error)
}

type HomeViewerReader interface {
	GetViewer(ctx context.Context, uid string) (domainhome.Viewer, error)
}

type HomeGetter interface {
	Execute(ctx context.Context, uid string) (domainhome.Content, error)
}

type HomeBaseGetter interface {
	ExecuteBase(ctx context.Context) (domainhome.Content, error)
}

type NotificationMarker interface {
	MarkRead(ctx context.Context, uid, notificationID string) error
}
