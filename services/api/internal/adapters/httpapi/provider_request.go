package httpapi

import (
	"net/http"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

type providerServiceRequest struct {
	Title           string `json:"title"`
	Description     string `json:"description"`
	CategoryID      string `json:"category_id"`
	DurationMinutes int    `json:"duration_minutes"`
	PriceCents      int    `json:"price_cents"`
	ImageURL        string `json:"image_url"`
	Published       bool   `json:"published"`
}

type publicationRequest struct {
	Published bool `json:"published"`
}

type availabilityRequest struct {
	AcceptingRequests bool `json:"accepting_requests"`
}

func decodeProviderServiceInput(w http.ResponseWriter, r *http.Request) (ports.ProviderServiceInput, bool) {
	var request providerServiceRequest
	if decodeJSONBody(w, r, &request) != nil {
		writeInvalidProviderInput(w)
		return ports.ProviderServiceInput{}, false
	}
	return ports.ProviderServiceInput{
		Title: request.Title, Description: request.Description, CategoryID: request.CategoryID,
		DurationMinutes: request.DurationMinutes, PriceCents: request.PriceCents,
		ImageURL: request.ImageURL, Published: request.Published,
	}, true
}
