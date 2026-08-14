package home

import (
	"context"
	"fmt"

	"golang.org/x/sync/errgroup"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
	"github.com/vendlydigital/help/services/api/internal/domain/promotions"
)

type GetHome struct {
	categories ports.CategoryReader
	catalog    ports.CatalogReader
	promotions ports.PromotionReader
	providers  ports.ProviderReader
	frame      ports.HomeFrameReader
}

func NewGetHome(
	categories ports.CategoryReader,
	catalog ports.CatalogReader,
	promotions ports.PromotionReader,
	providers ports.ProviderReader,
	frame ports.HomeFrameReader,
) *GetHome {
	return &GetHome{categories, catalog, promotions, providers, frame}
}

func (uc *GetHome) Execute(ctx context.Context) (domainhome.Content, error) {
	var (
		categoryList  []categories.Category
		serviceList   []catalog.Service
		promotionList []promotions.Promotion
		frame         domainhome.Frame
	)

	group, groupCtx := errgroup.WithContext(ctx)
	group.Go(func() (err error) {
		categoryList, err = uc.categories.ListPopular(groupCtx)
		return wrapSourceError("categories", err)
	})
	group.Go(func() (err error) {
		serviceList, err = uc.catalog.ListRecommended(groupCtx)
		return wrapSourceError("catalog", err)
	})
	group.Go(func() (err error) {
		promotionList, err = uc.promotions.ListActive(groupCtx)
		return wrapSourceError("promotions", err)
	})
	group.Go(func() (err error) {
		frame, err = uc.frame.GetFrame(groupCtx)
		return wrapSourceError("home frame", err)
	})
	if err := group.Wait(); err != nil {
		return domainhome.Content{}, err
	}

	providerMap, err := uc.providers.FindByIDs(ctx, providerIDs(serviceList))
	if err != nil {
		return domainhome.Content{}, fmt.Errorf("load providers: %w", err)
	}
	recommendations := make([]domainhome.RecommendedService, 0, len(serviceList))
	for _, service := range serviceList {
		provider, exists := providerMap[service.ProviderID]
		if !exists {
			return domainhome.Content{}, fmt.Errorf("provider %q not found", service.ProviderID)
		}
		recommendations = append(recommendations, domainhome.RecommendedService{
			Service: service, Provider: provider,
		})
	}

	return domainhome.Content{
		Frame: frame, Promotions: promotionList,
		Categories: categoryList, Services: recommendations,
	}, nil
}

func providerIDs(services []catalog.Service) []string {
	seen := make(map[string]struct{}, len(services))
	ids := make([]string, 0, len(services))
	for _, service := range services {
		if _, exists := seen[service.ProviderID]; !exists {
			seen[service.ProviderID] = struct{}{}
			ids = append(ids, service.ProviderID)
		}
	}
	return ids
}

func wrapSourceError(source string, err error) error {
	if err == nil {
		return nil
	}
	return fmt.Errorf("load %s: %w", source, err)
}
