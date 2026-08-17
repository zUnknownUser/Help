package ports

import (
	"context"

	"github.com/vendlydigital/help/services/api/internal/domain/matchmaking"
)

type MatchCandidateReader interface {
	ListCandidates(context.Context, matchmaking.Request) ([]matchmaking.Candidate, error)
}

type MatchRunRecorder interface {
	RecordMatchRun(context.Context, string, matchmaking.Request, []matchmaking.Match) error
}

type MatchPreferenceReader interface {
	GetMatchPreference(context.Context, string) (string, error)
}

type Matchmaker interface {
	Recommend(context.Context, matchmaking.Request) (matchmaking.Result, error)
}

type SemanticScorer interface {
	Score(context.Context, string, []matchmaking.Candidate) (map[string]float64, error)
}
