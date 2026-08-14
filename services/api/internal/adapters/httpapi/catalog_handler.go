package httpapi

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domaincatalog "github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

type CatalogHandler struct{ searcher ports.CatalogSearcher }

func NewCatalogHandler(searcher ports.CatalogSearcher) *CatalogHandler {
	return &CatalogHandler{searcher: searcher}
}

func (handler *CatalogHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	filters := domaincatalog.Filters{
		Query: query.Get("query"), CategoryID: query.Get("category_id"),
		Sort: query.Get("sort"), Cursor: query.Get("cursor"), Limit: queryLimit(r),
	}
	var err error
	if filters.MinPrice, err = optionalInt(query.Get("min_price_cents")); err != nil {
		writeInvalidFilters(w)
		return
	}
	if filters.MaxPrice, err = optionalInt(query.Get("max_price_cents")); err != nil {
		writeInvalidFilters(w)
		return
	}
	if filters.MinRating, err = optionalFloat(query.Get("min_rating")); err != nil {
		writeInvalidFilters(w)
		return
	}
	if filters.Verified, err = optionalBool(query.Get("verified")); err != nil {
		writeInvalidFilters(w)
		return
	}
	if filters.Latitude, err = optionalFloat(query.Get("latitude")); err != nil {
		writeInvalidFilters(w)
		return
	}
	if filters.Longitude, err = optionalFloat(query.Get("longitude")); err != nil {
		writeInvalidFilters(w)
		return
	}
	if (filters.Latitude == nil) != (filters.Longitude == nil) {
		writeInvalidFilters(w)
		return
	}
	if filters.RadiusKM, err = optionalFloat(query.Get("radius_km")); err != nil {
		writeInvalidFilters(w)
		return
	}
	if filters.Latitude != nil && filters.RadiusKM == nil {
		defaultRadius := 30.0
		filters.RadiusKM = &defaultRadius
	}
	if !validCatalogFilters(filters) {
		writeInvalidFilters(w)
		return
	}
	page, err := handler.searcher.Search(r.Context(), filters)
	if err != nil {
		if strings.Contains(err.Error(), "cursor") {
			writeInvalidFilters(w)
			return
		}
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"message": "Não foi possível buscar serviços."})
		return
	}
	items := make([]homeService, 0, len(page.Items))
	for _, item := range page.Items {
		items = append(items, catalogHomeService(item))
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": items, "next_cursor": page.NextCursor})
}

func catalogHomeService(item domaincatalog.Listing) homeService {
	service := item.Service
	return homeService{
		ID: service.ID, Title: service.Title, Rating: service.Rating, Reviews: service.Reviews,
		DurationMinutes: service.DurationMinutes, PriceCents: service.PriceCents,
		OldPriceCents: service.OldPriceCents, ImageURL: service.ImageURL,
		ImageAlignment: service.ImageAlignment, Badge: service.Badge,
		CategoryID: service.CategoryID, DistanceKM: service.DistanceKM,
		Provider: homeProvider{ID: service.ProviderID, Name: item.ProviderName, Verified: item.ProviderVerified},
	}
}

func validCatalogFilters(filters domaincatalog.Filters) bool {
	if filters.MinPrice != nil && *filters.MinPrice < 0 || filters.MaxPrice != nil && *filters.MaxPrice < 0 {
		return false
	}
	if filters.MinPrice != nil && filters.MaxPrice != nil && *filters.MinPrice > *filters.MaxPrice {
		return false
	}
	if filters.MinRating != nil && (*filters.MinRating < 0 || *filters.MinRating > 5) {
		return false
	}
	if filters.Latitude != nil && (*filters.Latitude < -90 || *filters.Latitude > 90 || *filters.Longitude < -180 || *filters.Longitude > 180) {
		return false
	}
	return filters.RadiusKM == nil || (*filters.RadiusKM > 0 && *filters.RadiusKM <= 200)
}

func optionalInt(value string) (*int, error) {
	if strings.TrimSpace(value) == "" {
		return nil, nil
	}
	parsed, err := strconv.Atoi(value)
	return &parsed, err
}

func optionalFloat(value string) (*float64, error) {
	if strings.TrimSpace(value) == "" {
		return nil, nil
	}
	parsed, err := strconv.ParseFloat(value, 64)
	return &parsed, err
}

func optionalBool(value string) (*bool, error) {
	if strings.TrimSpace(value) == "" {
		return nil, nil
	}
	parsed, err := strconv.ParseBool(value)
	return &parsed, err
}

func writeInvalidFilters(w http.ResponseWriter) {
	writeJSON(w, http.StatusBadRequest, map[string]string{"message": "Filtros inválidos."})
}
