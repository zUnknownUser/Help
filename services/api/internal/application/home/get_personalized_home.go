package home

import (
	"context"
	"fmt"

	"golang.org/x/sync/errgroup"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type GetHome struct {
	base    ports.HomeBaseGetter
	viewer  ports.HomeViewerReader
	catalog ports.CatalogSearcher
}

func NewGetHome(base ports.HomeBaseGetter, viewer ports.HomeViewerReader, catalog ports.CatalogSearcher) *GetHome {
	return &GetHome{base: base, viewer: viewer, catalog: catalog}
}

func (useCase *GetHome) Execute(
	ctx context.Context,
	uid string,
) (domainhome.Content, error) {
	var content domainhome.Content
	var viewer domainhome.Viewer
	group, groupCtx := errgroup.WithContext(ctx)
	group.Go(func() (err error) {
		content, err = useCase.base.ExecuteBase(groupCtx)
		if err != nil {
			return fmt.Errorf("load home base: %w", err)
		}
		return nil
	})
	group.Go(func() (err error) {
		viewer, err = useCase.viewer.GetViewer(groupCtx, uid)
		if err != nil {
			return fmt.Errorf("load home viewer: %w", err)
		}
		return nil
	})
	if err := group.Wait(); err != nil {
		return domainhome.Content{}, err
	}
	content.Viewer = viewer
	if viewer.Location.Latitude != nil && viewer.Location.Longitude != nil {
		radius := 30.0
		page, err := useCase.catalog.Search(ctx, catalog.Filters{
			Latitude: viewer.Location.Latitude, Longitude: viewer.Location.Longitude,
			RadiusKM: &radius, Sort: "distance", Limit: 12,
		})
		if err != nil {
			return domainhome.Content{}, fmt.Errorf("load nearby services: %w", err)
		}
		content.Services = make([]domainhome.RecommendedService, 0, len(page.Items))
		for _, item := range page.Items {
			content.Services = append(content.Services, domainhome.RecommendedService{
				Service:  item.Service,
				Provider: providers.Provider{ID: item.Service.ProviderID, Name: item.ProviderName, Verified: item.ProviderVerified},
			})
		}
	}
	return content, nil
}
