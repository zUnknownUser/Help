package home_test

import (
	"context"
	"testing"

	applicationhome "github.com/vendlydigital/help/services/api/internal/application/home"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
	"github.com/vendlydigital/help/services/api/internal/domain/promotions"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type categoryReaderStub struct{ values []categories.Category }

func (s categoryReaderStub) ListPopular(context.Context) ([]categories.Category, error) {
	return s.values, nil
}

type catalogReaderStub struct{ values []catalog.Service }

func (s catalogReaderStub) ListRecommended(context.Context) ([]catalog.Service, error) {
	return s.values, nil
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

func TestGetHomeComposesAllModulesInOneResult(t *testing.T) {
	t.Parallel()

	service := catalog.Service{ID: "cleaning", ProviderID: "provider-1", Title: "Limpeza residencial"}
	provider := providers.Provider{ID: "provider-1", Name: "Parceiro Help", Verified: true}
	useCase := applicationhome.NewGetHome(
		categoryReaderStub{values: []categories.Category{{ID: "cleaning", Name: "Limpeza"}}},
		catalogReaderStub{values: []catalog.Service{service}},
		promotionReaderStub{values: []promotions.Promotion{{ID: "air-conditioning", Title: "A gente resolve rápido."}}},
		providerReaderStub{values: map[string]providers.Provider{provider.ID: provider}},
		frameReaderStub{value: domainhome.Frame{SearchPlaceholder: "Busque por um serviço"}},
	)

	content, err := useCase.Execute(context.Background())

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

func TestGetHomeFailsWhenServiceProviderDoesNotExist(t *testing.T) {
	t.Parallel()

	useCase := applicationhome.NewGetHome(
		categoryReaderStub{},
		catalogReaderStub{values: []catalog.Service{{ID: "cleaning", ProviderID: "missing"}}},
		promotionReaderStub{},
		providerReaderStub{values: map[string]providers.Provider{}},
		frameReaderStub{},
	)

	_, err := useCase.Execute(context.Background())

	if err == nil {
		t.Fatal("Execute() deveria falhar para provider inexistente")
	}
}
