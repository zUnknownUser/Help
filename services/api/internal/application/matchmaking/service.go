package matchmaking

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainmatch "github.com/vendlydigital/help/services/api/internal/domain/matchmaking"
)

type Service struct {
	candidates  ports.MatchCandidateReader
	recorder    ports.MatchRunRecorder
	preferences ports.MatchPreferenceReader
	semantic    ports.SemanticScorer
	scorer      domainmatch.Scorer
	now         func() time.Time
}

func NewService(candidates ports.MatchCandidateReader, recorder ports.MatchRunRecorder, preferences ports.MatchPreferenceReader, semantic ports.SemanticScorer, now func() time.Time) *Service {
	return &Service{candidates: candidates, recorder: recorder, preferences: preferences, semantic: semantic, scorer: domainmatch.Scorer{}, now: now}
}

func (service *Service) Recommend(ctx context.Context, request domainmatch.Request) (domainmatch.Result, error) {
	request.ViewerUID = strings.TrimSpace(request.ViewerUID)
	if request.ViewerUID == "" {
		return domainmatch.Result{}, fmt.Errorf("viewer uid is required")
	}
	if request.Now.IsZero() {
		request.Now = service.now()
	}
	candidates, err := service.candidates.ListCandidates(ctx, request)
	if err != nil {
		return domainmatch.Result{}, fmt.Errorf("list match candidates: %w", err)
	}
	runID := uuid.NewString()
	matches := service.scorer.Rank(request, candidates)
	if service.semantic != nil && service.preferences != nil {
		preference, preferenceErr := service.preferences.GetMatchPreference(ctx, request.ViewerUID)
		if preferenceErr != nil {
			slog.WarnContext(ctx, "matchmaking preference unavailable", "run_id", runID, "viewer_uid", request.ViewerUID, "error", preferenceErr)
		} else if preference = strings.TrimSpace(preference); preference != "" {
			semantic, semanticErr := service.semantic.Score(ctx, preference, semanticShortlist(candidates, matches))
			if semanticErr != nil {
				slog.WarnContext(ctx, "semantic matchmaking unavailable", "run_id", runID, "viewer_uid", request.ViewerUID, "error", semanticErr)
			} else {
				matches = service.scorer.RankWithSemantic(request, candidates, semantic)
			}
		}
	}
	if len(matches) > 0 && service.recorder != nil {
		if err := service.recorder.RecordMatchRun(ctx, runID, request, matches); err != nil {
			slog.WarnContext(ctx, "matchmaking audit recording failed", "run_id", runID, "viewer_uid", request.ViewerUID, "error", err)
		}
	}
	return domainmatch.Result{RunID: runID, Matches: matches}, nil
}

func semanticShortlist(candidates []domainmatch.Candidate, matches []domainmatch.Match) []domainmatch.Candidate {
	byService := make(map[string]domainmatch.Candidate, len(candidates))
	for _, candidate := range candidates {
		byService[candidate.Listing.Service.ID] = candidate
	}
	result := make([]domainmatch.Candidate, 0, len(matches))
	for _, match := range matches {
		if candidate, ok := byService[match.Listing.Service.ID]; ok {
			result = append(result, candidate)
		}
	}
	return result
}
