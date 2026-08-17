package home_test

import (
	"context"
	"testing"

	applicationhome "github.com/vendlydigital/help/services/api/internal/application/home"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
	"github.com/vendlydigital/help/services/api/internal/domain/matchmaking"
	"github.com/vendlydigital/help/services/api/internal/domain/promotions"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type categoryReaderStub struct{ values []categories.Category }

func (s categoryReaderStub) ListPopular(context.Context) ([]categories.Category, error) {
	return s.values, nil
}

type matchmakerStub struct{ values []catalog.Listing }

func (s matchmakerStub) Recommend(context.Context, matchmaking.Request) (matchmaking.Result, error) {
	matches := make([]matchmaking.Match, 0, len(s.values))
	for _, item := range s.values {
		matches = append(matches, matchmaking.Match{Listing: item})
	}
	return matchmaking.Result{RunID: "run-id", Matches: matches}, nil
}

type promotionReaderStub struct{ values []promotions.Promotion }

func (s promotionReaderStub) ListActive(context.Context) ([]promotions.Promotion, error) {
	return s.values, nil
}

type providerReaderStub struct{ values map[string]providers.Provider }

func (s providerReaderStub) FindByIDs(context.Context, []string) (map[string]providers.Provider, error) {
	return s.values, nil
}

type frameReaderStub struct{ value domainhome.Frame }

func (s frameReaderStub) GetFrame(context.Context) (domainhome.Frame, error) {
	return s.value, nil
}

type viewerReaderStub struct{ value domainhome.Viewer }

func (s viewerReaderStub) GetViewer(context.Context, string) (domainhome.Viewer, error) {
	return s.value, nil
}

func TestGetHomeComposesAllModulesInOneResult(t *testing.T) {
	t.Parallel()

	service := catalog.Service{ID: "cleaning", ProviderID: "provider-1", Title: "Limpeza residencial"}
	provider := providers.Provider{ID: "provider-1", Name: "Parceiro Help", Verified: true}
	base := applicationhome.NewGetHomeBase(
		categoryReaderStub{values: []categories.Category{{ID: "cleaning", Name: "Limpeza"}}},
		promotionReaderStub{values: []promotions.Promotion{{ID: "air-conditioning", Title: "A gente resolve rápido."}}},
		frameReaderStub{value: domainhome.Frame{SearchPlaceholder: "Busque por um serviço"}},
	)
	latitude, longitude := -3.1, -60.0
	useCase := applicationhome.NewGetHome(
		base,
		viewerReaderStub{value: domainhome.Viewer{
			UnreadNotificationCount: 2,
			Location:                domainhome.Location{Latitude: &latitude, Longitude: &longitude},
		}},
		matchmakerStub{values: []catalog.Listing{{
			Service: service, ProviderName: provider.Name, ProviderVerified: provider.Verified,
		}}},
	)

	content, err := useCase.Execute(context.Background(), "firebase-uid")

	if err != nil {
		t.Fatalf("Execute() error = %v", err)
	}
	if len(content.Categories) != 1 || len(content.Promotions) != 1 || len(content.Services) != 1 {
		t.Fatalf("conteúdo incompleto: %+v", content)
	}
	if content.Services[0].Provider != provider {
		t.Fatalf("provider = %+v; esperado %+v", content.Services[0].Provider, provider)
	}
	if content.Frame.SearchPlaceholder != "Busque por um serviço" {
		t.Fatalf("frame não foi composto: %+v", content.Frame)
	}
}

func TestGetHomeDoesNotExposeGlobalServicesWithoutUserLocation(t *testing.T) {
	t.Parallel()

	base := applicationhome.NewGetHomeBase(
		categoryReaderStub{},
		promotionReaderStub{},
		frameReaderStub{},
	)
	useCase := applicationhome.NewGetHome(base, viewerReaderStub{}, matchmakerStub{
		values: []catalog.Listing{{Service: catalog.Service{ID: "must-not-leak"}}},
	})

	content, err := useCase.Execute(context.Background(), "firebase-uid")

	if err != nil || len(content.Services) != 0 {
		t.Fatalf("serviços sem localização = %+v, erro = %v", content.Services, err)
	}
}
