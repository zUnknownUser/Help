package matchmaking

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainmatch "github.com/vendlydigital/help/services/api/internal/domain/matchmaking"
)

func TestRepositoryFindsEligibleCandidateAndRecordsRun(t *testing.T) {
	databaseURL := os.Getenv("TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("TEST_DATABASE_URL not configured")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()

	suffix := uuid.NewString()
	customerUID, providerUID := "match-customer-"+suffix, "match-provider-"+suffix
	providerID, categoryID, serviceID := "provider-"+suffix, "category-"+suffix, "service-"+suffix
	defer cleanupMatchmakingFixture(pool, customerUID, providerUID, providerID, categoryID)
	insertFixture(t, pool, "user_profiles", []string{"firebase_uid", "email", "display_name", "active_role"}, customerUID, customerUID+"@example.com", "Cliente", "customer")
	insertFixture(t, pool, "user_profiles", []string{"firebase_uid", "email", "display_name", "active_role"}, providerUID, providerUID+"@example.com", "Profissional", "provider")
	insertFixture(t, pool, "user_roles", []string{"firebase_uid", "role"}, customerUID, "customer")
	insertFixture(t, pool, "user_roles", []string{"firebase_uid", "role"}, providerUID, "provider")
	insertFixture(t, pool, "categories", []string{"id", "name", "icon_key", "position"}, categoryID, "Limpeza", "cleaning", 900)
	insertFixture(t, pool, "providers", []string{"id", "name", "verified", "active", "accepting_requests", "owner_uid", "onboarding_status", "service_radius_km"}, providerID, "Profissional", true, true, true, providerUID, "approved", 20)
	insertFixture(t, pool, "user_addresses", []string{"firebase_uid", "label", "formatted_address", "is_default", "latitude", "longitude"}, providerUID, "Atendimento", "Manaus, AM", true, -3.0816, -59.978)
	insertFixture(t, pool, "services", []string{"id", "provider_id", "category_id", "title", "description", "rating", "reviews", "duration_minutes", "price_cents", "old_price_cents", "active", "published_at"}, serviceID, providerID, categoryID, "Limpeza residencial", "Limpeza completa", 4.8, 10, 60, 12000, nil, true, time.Now())

	repository := NewRepository(pool)
	request := domainmatch.Request{ViewerUID: customerUID, Latitude: -3.0816, Longitude: -59.978, RadiusKM: 30, Limit: 12, Now: time.Now().UTC()}
	candidates, err := repository.ListCandidates(ctx, request)
	found := false
	for _, candidate := range candidates {
		found = found || candidate.Listing.Service.ID == serviceID
	}
	if err != nil || !found {
		t.Fatalf("candidates=%+v error=%v", candidates, err)
	}
	matches := (domainmatch.Scorer{}).Rank(request, candidates)
	runID := uuid.NewString()
	if err := repository.RecordMatchRun(ctx, runID, request, matches); err != nil {
		t.Fatalf("RecordMatchRun() error=%v", err)
	}
	var count int
	query, args, _ := database.Query.Select("COUNT(*)").From("matchmaking_results").Where("run_id = ?::uuid", runID).ToSql()
	if err := pool.QueryRow(ctx, query, args...).Scan(&count); err != nil || count != len(matches) {
		t.Fatalf("recorded results=%d error=%v", count, err)
	}
}

func insertFixture(t *testing.T, pool *pgxpool.Pool, table string, columns []string, values ...any) {
	t.Helper()
	query, args, err := database.Query.Insert(table).Columns(columns...).Values(values...).ToSql()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(context.Background(), query, args...); err != nil {
		t.Fatal(err)
	}
}

func cleanupMatchmakingFixture(pool *pgxpool.Pool, customerUID, providerUID, providerID, categoryID string) {
	ctx := context.Background()
	statements := []struct {
		table, condition string
		value            any
	}{
		{"matchmaking_runs", "viewer_uid = ?", customerUID},
		{"services", "provider_id = ?", providerID},
		{"user_addresses", "firebase_uid IN (?, ?)", []any{customerUID, providerUID}},
		{"providers", "id = ?", providerID},
		{"categories", "id = ?", categoryID},
		{"user_profiles", "firebase_uid IN (?, ?)", []any{customerUID, providerUID}},
	}
	for _, statement := range statements {
		builder := database.Query.Delete(statement.table)
		if values, ok := statement.value.([]any); ok {
			builder = builder.Where(statement.condition, values...)
		} else {
			builder = builder.Where(statement.condition, statement.value)
		}
		query, args, err := builder.ToSql()
		if err == nil {
			_, _ = pool.Exec(ctx, query, args...)
		}
	}
}
