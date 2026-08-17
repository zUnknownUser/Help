package matchmaking

import (
	"hash/fnv"
	"math"
	"sort"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

const AlgorithmVersion = "home-v1"

type Request struct {
	ViewerUID  string
	Latitude   float64
	Longitude  float64
	RadiusKM   float64
	Limit      int
	Query      string
	CategoryID string
	Now        time.Time
}

type Candidate struct {
	Listing           catalog.Listing
	Latitude          float64
	Longitude         float64
	ServiceRadiusKM   float64
	YearsExperience   int
	ProviderCreatedAt time.Time
	TotalRequests     int
	CompletedRequests int
	CancelledRequests int
	ActiveRequests    int
}

type Reason struct {
	Code  string
	Label string
}

type Match struct {
	Listing catalog.Listing
	Score   float64
	Reasons []Reason
}

type Result struct {
	RunID   string
	Matches []Match
}

type Scorer struct{}

func (Scorer) Rank(request Request, candidates []Candidate) []Match {
	return (Scorer{}).RankWithSemantic(request, candidates, nil)
}

func (Scorer) RankWithSemantic(request Request, candidates []Candidate, semantic map[string]float64) []Match {
	matches := make([]Match, 0, len(candidates))
	for _, candidate := range candidates {
		distance := haversineKM(request.Latitude, request.Longitude, candidate.Latitude, candidate.Longitude)
		allowedRadius := math.Min(request.RadiusKM, candidate.ServiceRadiusKM)
		if allowedRadius <= 0 || distance > allowedRadius {
			continue
		}
		candidate.Listing.Service.DistanceKM = &distance
		match := score(request, candidate, distance, allowedRadius)
		if semanticScore, ok := semantic[candidate.Listing.Service.ID]; ok {
			match.Score = .85*match.Score + .15*clamp(semanticScore)
			if semanticScore >= .70 {
				match.Reasons = prependReason(match.Reasons, Reason{Code: "semantic_match", Label: "Combina com o que você procura"})
			}
		}
		matches = append(matches, match)
	}
	sort.SliceStable(matches, func(i, j int) bool {
		if matches[i].Score == matches[j].Score {
			return matches[i].Listing.Service.ID < matches[j].Listing.Service.ID
		}
		return matches[i].Score > matches[j].Score
	})
	return diversify(matches, normalizedLimit(request.Limit), 2)
}

func prependReason(reasons []Reason, reason Reason) []Reason {
	result := make([]Reason, 0, 2)
	result = append(result, reason)
	for _, current := range reasons {
		if current.Code != reason.Code && len(result) < 2 {
			result = append(result, current)
		}
	}
	return result
}

func score(request Request, candidate Candidate, distance, radius float64) Match {
	service := candidate.Listing.Service
	distanceScore := 1 - clamp(distance/radius)
	ratingConfidence := float64(service.Reviews) / float64(service.Reviews+5)
	ratingScore := ratingConfidence*(service.Rating/5) + (1-ratingConfidence)*0.65
	resolved := candidate.CompletedRequests + candidate.CancelledRequests
	reliabilityConfidence := float64(resolved) / float64(resolved+5)
	reliability := 0.70
	if resolved > 0 {
		reliability = reliabilityConfidence*(float64(candidate.CompletedRequests)/float64(resolved)) + (1-reliabilityConfidence)*0.70
	}
	availability := 1 / float64(1+candidate.ActiveRequests)
	experience := clamp(float64(candidate.YearsExperience) / 10)
	verified := 0.0
	if candidate.Listing.ProviderVerified {
		verified = 1
	}
	exploration := newProviderBoost(request, candidate)
	total := 0.32*distanceScore + 0.23*ratingScore + 0.16*reliability +
		0.12*availability + 0.10*experience + 0.04*verified + 0.03*exploration
	return Match{Listing: candidate.Listing, Score: total, Reasons: reasons(candidate, distance)}
}

func reasons(candidate Candidate, distance float64) []Reason {
	result := make([]Reason, 0, 2)
	add := func(code, label string) {
		if len(result) < 2 {
			result = append(result, Reason{Code: code, Label: label})
		}
	}
	if distance <= 5 {
		add("nearby", "Perto de você")
	}
	if candidate.Listing.Service.Rating >= 4.5 && candidate.Listing.Service.Reviews >= 3 {
		add("top_rated", "Muito bem avaliado")
	}
	resolved := candidate.CompletedRequests + candidate.CancelledRequests
	if resolved >= 5 && float64(candidate.CompletedRequests)/float64(resolved) >= .85 {
		add("reliable", "Alta taxa de conclusão")
	}
	if candidate.TotalRequests < 3 {
		add("new_professional", "Novo na Help")
	}
	if candidate.ActiveRequests <= 1 {
		add("available", "Boa disponibilidade")
	}
	if candidate.YearsExperience >= 5 {
		add("experienced", "Profissional experiente")
	}
	if len(result) == 0 {
		add("recommended", "Recomendado para você")
	}
	return result
}

func newProviderBoost(request Request, candidate Candidate) float64 {
	if candidate.TotalRequests >= 3 {
		return 0
	}
	day := request.Now.UTC().Format("2006-01-02")
	hash := fnv.New32a()
	_, _ = hash.Write([]byte(request.ViewerUID + ":" + candidate.Listing.Service.ProviderID + ":" + day))
	return .7 + .3*float64(hash.Sum32()%1000)/999
}

func diversify(matches []Match, limit, maxPerProvider int) []Match {
	result := make([]Match, 0, min(limit, len(matches)))
	counts := make(map[string]int)
	for _, match := range matches {
		providerID := match.Listing.Service.ProviderID
		if counts[providerID] >= maxPerProvider {
			continue
		}
		result = append(result, match)
		counts[providerID]++
		if len(result) == limit {
			break
		}
	}
	return result
}

func normalizedLimit(value int) int {
	if value < 1 {
		return 12
	}
	return min(value, 30)
}

func clamp(value float64) float64 { return math.Max(0, math.Min(1, value)) }

func haversineKM(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusKM = 6371
	toRadians := func(value float64) float64 { return value * math.Pi / 180 }
	dLat, dLon := toRadians(lat2-lat1), toRadians(lon2-lon1)
	a := math.Sin(dLat/2)*math.Sin(dLat/2) + math.Cos(toRadians(lat1))*math.Cos(toRadians(lat2))*math.Sin(dLon/2)*math.Sin(dLon/2)
	return earthRadiusKM * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}
