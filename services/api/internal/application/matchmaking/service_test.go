package matchmaking_test

import (
	"context"
	"testing"
	"time"

	applicationmatch "github.com/vendlydigital/help/services/api/internal/application/matchmaking"
	domainmatch "github.com/vendlydigital/help/services/api/internal/domain/matchmaking"
)

type candidateReaderStub struct{ requests []domainmatch.Request }

func (stub *candidateReaderStub) ListCandidates(_ context.Context, request domainmatch.Request) ([]domainmatch.Candidate, error) {
	stub.requests = append(stub.requests, request)
	return nil, nil
}

func TestServiceNormalizesTimeAndReturnsTraceableRun(t *testing.T) {
	reader := &candidateReaderStub{}
	now := time.Date(2026, 8, 17, 12, 0, 0, 0, time.UTC)
	service := applicationmatch.NewService(reader, nil, nil, nil, func() time.Time { return now })

	result, err := service.Recommend(context.Background(), domainmatch.Request{ViewerUID: " customer "})

	if err != nil || result.RunID == "" {
		t.Fatalf("result = %+v, error = %v", result, err)
	}
	if reader.requests[0].ViewerUID != "customer" || !reader.requests[0].Now.Equal(now) {
		t.Fatalf("request not normalized: %+v", reader.requests[0])
	}
}
