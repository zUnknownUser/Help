package httpapi_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/adapters/httpapi"
	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/categories"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
	"github.com/vendlydigital/help/services/api/internal/domain/promotions"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type homeGetterStub struct {
	content domainhome.Content
	err     error
}

func (s homeGetterStub) Execute(context.Context) (domainhome.Content, error) {
	return s.content, s.err
}

func TestHomeHandlerReturnsCompleteScreenContract(t *testing.T) {
	t.Parallel()

	content := domainhome.Content{
		Frame: domainhome.Frame{
			Location:          domainhome.Location{Address: "Av. Eduardo Ribeiro, 520", AvailabilityLabel: "Serviços disponíveis na sua região"},
			SearchPlaceholder: "Busque por um serviço ou profissional",
			Benefits:          []domainhome.Benefit{{ID: "verified", Label: "Profissionais\nverificados", IconKey: "verified"}},
		},
		Promotions: []promotions.Promotion{{ID: "promo-1", Title: "A gente resolve rápido."}},
		Categories: []categories.Category{{ID: "cleaning", Name: "Limpeza\nresidencial", IconKey: "home"}},
		Services: []domainhome.RecommendedService{{
			Service:  catalog.Service{ID: "service-1", Title: "Limpeza residencial", PriceCents: 7900},
			Provider: providers.Provider{ID: "provider-1", Name: "Parceiro Help", Verified: true},
		}},
	}
	handler := httpapi.NewHomeHandler(homeGetterStub{content: content})
	req := httptest.NewRequest(http.MethodGet, "/v1/home", nil)
	res := httptest.NewRecorder()

	handler.ServeHTTP(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("status = %d; esperado %d", res.Code, http.StatusOK)
	}
	var body map[string]any
	if err := json.Unmarshal(res.Body.Bytes(), &body); err != nil {
		t.Fatalf("JSON inválido: %v", err)
	}
	data, ok := body["data"].(map[string]any)
	if !ok {
		t.Fatalf("resposta sem data: %s", res.Body.String())
	}
	for _, field := range []string{"location", "search_placeholder", "promotions", "categories", "recommended_services", "benefits"} {
		if _, exists := data[field]; !exists {
			t.Errorf("campo %q ausente", field)
		}
	}
	promotion := data["promotions"].([]any)[0].(map[string]any)
	if _, ok := promotion["features"].([]any); !ok {
		t.Fatalf("features deve ser array vazio, resposta: %s", res.Body.String())
	}
	if _, ok := promotion["actions"].([]any); !ok {
		t.Fatalf("actions deve ser array vazio, resposta: %s", res.Body.String())
	}
}
