package matchmaking

import (
	"context"
	"fmt"
	"math"
	"strings"

	sq "github.com/Masterminds/squirrel"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainmatch "github.com/vendlydigital/help/services/api/internal/domain/matchmaking"
)

const candidatePoolSize = 200

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (repository *Repository) GetMatchPreference(ctx context.Context, viewerUID string) (string, error) {
	query, args, err := database.Query.Select("service.title", "service.description", "COALESCE(category.name, '')").
		From("service_requests request").Join("services service ON service.id = request.service_id").
		LeftJoin("categories category ON category.id = service.category_id").
		Where("request.customer_uid = ?", viewerUID).
		Where("request.status IN (?, ?, ?)", "accepted", "in_progress", "completed").
		OrderBy("request.updated_at DESC", "request.id DESC").Limit(8).ToSql()
	if err != nil {
		return "", fmt.Errorf("build match preference: %w", err)
	}
	rows, err := repository.pool.Query(ctx, query, args...)
	if err != nil {
		return "", fmt.Errorf("query match preference: %w", err)
	}
	defer rows.Close()
	parts := make([]string, 0, 8)
	for rows.Next() {
		var title, description, category string
		if err := rows.Scan(&title, &description, &category); err != nil {
			return "", fmt.Errorf("scan match preference: %w", err)
		}
		parts = append(parts, strings.TrimSpace(title+" "+category+" "+description))
	}
	if err := rows.Err(); err != nil {
		return "", fmt.Errorf("iterate match preference: %w", err)
	}
	return strings.Join(parts, ". "), nil
}

func (repository *Repository) ListCandidates(ctx context.Context, request domainmatch.Request) ([]domainmatch.Candidate, error) {
	radius := request.RadiusKM
	if radius <= 0 || radius > 100 {
		radius = 30
	}
	latitudeDelta := radius / 111.045
	longitudeDelta := radius / (111.045 * math.Max(math.Cos(request.Latitude*math.Pi/180), .01))

	query := database.Query.Select(
		"service.id", "service.provider_id", "COALESCE(service.category_id, '')", "service.title", "service.description",
		"service.rating::float8", "service.reviews", "service.duration_minutes", "service.price_cents", "service.old_price_cents",
		"service.image_url", "service.image_alignment", "service.badge", "service.created_at", "service.updated_at",
		"provider.name", "provider.verified", "COALESCE(provider.years_experience, 0)", "provider.service_radius_km", "provider.created_at",
		"address.latitude", "address.longitude",
	).From("services service").
		Join("providers provider ON provider.id = service.provider_id").
		Join("user_addresses address ON address.firebase_uid = provider.owner_uid AND address.is_default AND address.active").
		Where("service.active").Where("service.deleted_at IS NULL").
		Where("provider.active").Where("provider.accepting_requests").Where("provider.onboarding_status = ?", "approved").
		Where("provider.owner_uid <> ?", request.ViewerUID).
		Where("address.latitude BETWEEN ? AND ?", request.Latitude-latitudeDelta, request.Latitude+latitudeDelta).
		Where("address.longitude BETWEEN ? AND ?", request.Longitude-longitudeDelta, request.Longitude+longitudeDelta).
		OrderBy("service.updated_at DESC", "service.id").Limit(candidatePoolSize)
	if request.CategoryID != "" {
		query = query.Where("service.category_id = ?", request.CategoryID)
	}
	querySQL, args, err := query.ToSql()
	if err != nil {
		return nil, fmt.Errorf("build matchmaking candidates: %w", err)
	}
	rows, err := repository.pool.Query(ctx, querySQL, args...)
	if err != nil {
		return nil, fmt.Errorf("query matchmaking candidates: %w", err)
	}
	defer rows.Close()

	candidates := make([]domainmatch.Candidate, 0, candidatePoolSize)
	for rows.Next() {
		var candidate domainmatch.Candidate
		service, listing := &candidate.Listing.Service, &candidate.Listing
		if err := rows.Scan(
			&service.ID, &service.ProviderID, &service.CategoryID, &service.Title, &service.Description,
			&service.Rating, &service.Reviews, &service.DurationMinutes, &service.PriceCents, &service.OldPriceCents,
			&service.ImageURL, &service.ImageAlignment, &service.Badge, &service.CreatedAt, &service.UpdatedAt,
			&listing.ProviderName, &listing.ProviderVerified, &candidate.YearsExperience, &candidate.ServiceRadiusKM, &candidate.ProviderCreatedAt,
			&candidate.Latitude, &candidate.Longitude,
		); err != nil {
			return nil, fmt.Errorf("scan matchmaking candidate: %w", err)
		}
		candidates = append(candidates, candidate)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate matchmaking candidates: %w", err)
	}
	rows.Close()
	if err := repository.loadMetrics(ctx, candidates); err != nil {
		return nil, err
	}
	return candidates, nil
}

func (repository *Repository) loadMetrics(ctx context.Context, candidates []domainmatch.Candidate) error {
	providerIndexes := make(map[string][]int)
	providerIDs := make([]string, 0, len(candidates))
	for index, candidate := range candidates {
		providerID := candidate.Listing.Service.ProviderID
		if _, found := providerIndexes[providerID]; !found {
			providerIDs = append(providerIDs, providerID)
		}
		providerIndexes[providerID] = append(providerIndexes[providerID], index)
	}
	if len(providerIDs) == 0 {
		return nil
	}
	query, args, err := database.Query.Select(
		"provider_id", "COUNT(*)", "COUNT(*) FILTER (WHERE status = 'completed')",
		"COUNT(*) FILTER (WHERE status = 'cancelled')",
		"COUNT(*) FILTER (WHERE status IN ('pending','accepted','in_progress'))",
	).From("service_requests").Where(sq.Eq{"provider_id": providerIDs}).GroupBy("provider_id").ToSql()
	if err != nil {
		return fmt.Errorf("build matchmaking metrics: %w", err)
	}
	rows, err := repository.pool.Query(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("query matchmaking metrics: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var providerID string
		var total, completed, cancelled, active int
		if err := rows.Scan(&providerID, &total, &completed, &cancelled, &active); err != nil {
			return fmt.Errorf("scan matchmaking metrics: %w", err)
		}
		for _, index := range providerIndexes[providerID] {
			candidates[index].TotalRequests = total
			candidates[index].CompletedRequests = completed
			candidates[index].CancelledRequests = cancelled
			candidates[index].ActiveRequests = active
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate matchmaking metrics: %w", err)
	}
	return nil
}

func (repository *Repository) RecordMatchRun(ctx context.Context, runID string, request domainmatch.Request, matches []domainmatch.Match) error {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin match run: %w", err)
	}
	defer tx.Rollback(ctx)
	runSQL, runArgs, err := database.Query.Insert("matchmaking_runs").
		Columns("id", "viewer_uid", "latitude", "longitude", "radius_km", "algorithm_version", "result_count", "created_at").
		Values(runID, request.ViewerUID, request.Latitude, request.Longitude, request.RadiusKM, domainmatch.AlgorithmVersion, len(matches), request.Now).ToSql()
	if err != nil {
		return fmt.Errorf("build match run: %w", err)
	}
	if _, err := tx.Exec(ctx, runSQL, runArgs...); err != nil {
		return fmt.Errorf("insert match run: %w", err)
	}
	results := database.Query.Insert("matchmaking_results").
		Columns("run_id", "service_id", "provider_id", "position", "score", "reason_codes")
	for position, match := range matches {
		codes := make([]string, 0, len(match.Reasons))
		for _, reason := range match.Reasons {
			codes = append(codes, reason.Code)
		}
		results = results.Values(runID, match.Listing.Service.ID, match.Listing.Service.ProviderID, position+1, match.Score, codes)
	}
	resultsSQL, resultsArgs, err := results.ToSql()
	if err != nil {
		return fmt.Errorf("build match results: %w", err)
	}
	if _, err := tx.Exec(ctx, resultsSQL, resultsArgs...); err != nil {
		return fmt.Errorf("insert match results: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit match run: %w", err)
	}
	return nil
}
