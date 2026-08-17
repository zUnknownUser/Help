package matchmaking

import (
	"testing"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

func TestRankEnforcesProviderRadiusAndOrdersStrongCandidate(t *testing.T) {
	now := time.Date(2026, 8, 17, 12, 0, 0, 0, time.UTC)
	request := Request{ViewerUID: "customer", Latitude: -3.10, Longitude: 0, RadiusKM: 30, Limit: 12, Now: now}
	candidates := []Candidate{
		candidate("strong", "provider-a", -3.101, 5, 4.9, 30, 18, 1),
		candidate("outside-provider-area", "provider-b", -3.20, 2, 5, 100, 50, 0),
		candidate("new", "provider-c", -3.102, 10, 0, 0, 0, 0),
	}

	matches := (Scorer{}).Rank(request, candidates)

	if len(matches) != 2 {
		t.Fatalf("matches = %d; want 2", len(matches))
	}
	if matches[0].Listing.Service.ID != "strong" {
		t.Fatalf("first = %s; want strong", matches[0].Listing.Service.ID)
	}
	if matches[0].Listing.Service.DistanceKM == nil {
		t.Fatal("distance was not calculated")
	}
}

func TestRankDiversifiesProviders(t *testing.T) {
	request := Request{ViewerUID: "customer", Latitude: 0, Longitude: 0, RadiusKM: 30, Limit: 3, Now: time.Now()}
	candidates := []Candidate{
		candidate("a1", "a", 0, 30, 5, 50, 40, 0),
		candidate("a2", "a", 0, 30, 5, 50, 40, 0),
		candidate("a3", "a", 0, 30, 5, 50, 40, 0),
		candidate("b1", "b", 0, 30, 4, 5, 3, 0),
	}

	matches := (Scorer{}).Rank(request, candidates)

	if len(matches) != 3 || matches[2].Listing.Service.ProviderID != "b" {
		t.Fatalf("provider diversity not applied: %+v", matches)
	}
}

func TestNewProfessionalGetsExplainableExploration(t *testing.T) {
	request := Request{ViewerUID: "customer", Latitude: 0, Longitude: 0, RadiusKM: 30, Limit: 1, Now: time.Now()}
	matches := (Scorer{}).Rank(request, []Candidate{candidate("new", "provider", 0, 30, 0, 0, 0, 0)})

	found := false
	for _, reason := range matches[0].Reasons {
		found = found || reason.Code == "new_professional"
	}
	if !found {
		t.Fatalf("new professional reason missing: %+v", matches[0].Reasons)
	}
}

func candidate(id, provider string, latitude, radius, rating float64, reviews, completed, active int) Candidate {
	return Candidate{
		Listing:  catalog.Listing{Service: catalog.Service{ID: id, ProviderID: provider, Rating: rating, Reviews: reviews}},
		Latitude: latitude, Longitude: 0, ServiceRadiusKM: radius,
		TotalRequests: completed, CompletedRequests: completed, ActiveRequests: active,
	}
}
