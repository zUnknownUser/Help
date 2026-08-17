package httpapi

import (
	"encoding/json"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

func TestHomeResponseKeepsEmptyCategoryInServiceContract(t *testing.T) {
	t.Parallel()
	response := newHomeResponse(domainhome.Content{
		Services: []domainhome.RecommendedService{{
			Service:  catalog.Service{ID: "service-1", CategoryID: ""},
			Provider: providers.Provider{ID: "provider-1"},
		}},
	})
	raw, err := json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	var envelope map[string]any
	if err := json.Unmarshal(raw, &envelope); err != nil {
		t.Fatal(err)
	}
	data := envelope["data"].(map[string]any)
	service := data["recommended_services"].([]any)[0].(map[string]any)
	categoryID, exists := service["category_id"]
	if !exists || categoryID != "" {
		t.Fatalf("category_id must be present and empty, service = %+v", service)
	}
}
