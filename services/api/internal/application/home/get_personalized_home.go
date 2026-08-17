package home

import (
	"context"
	"fmt"

	"golang.org/x/sync/errgroup"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
	domainmatch "github.com/vendlydigital/help/services/api/internal/domain/matchmaking"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type GetHome struct {
	base    ports.HomeBaseGetter
	viewer  ports.HomeViewerReader
	matcher ports.Matchmaker
}

func NewGetHome(base ports.HomeBaseGetter, viewer ports.HomeViewerReader, matcher ports.Matchmaker) *GetHome {
	return &GetHome{base: base, viewer: viewer, matcher: matcher}
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
		result, err := useCase.matcher.Recommend(ctx, domainmatch.Request{
			ViewerUID: uid, Latitude: *viewer.Location.Latitude, Longitude: *viewer.Location.Longitude,
			RadiusKM: 30, Limit: 12,
		})
		if err != nil {
			return domainhome.Content{}, fmt.Errorf("load matched services: %w", err)
		}
		content.MatchRunID = result.RunID
		content.Services = make([]domainhome.RecommendedService, 0, len(result.Matches))
		for _, match := range result.Matches {
			item := match.Listing
			content.Services = append(content.Services, domainhome.RecommendedService{
				Service:      item.Service,
				Provider:     providers.Provider{ID: item.Service.ProviderID, Name: item.ProviderName, Verified: item.ProviderVerified},
				MatchReasons: match.Reasons,
			})
		}
	}
	return content, nil
}
