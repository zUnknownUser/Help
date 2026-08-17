package catalog

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	domaincatalog "github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (r *Repository) ListRecommended(ctx context.Context) ([]domaincatalog.Service, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT service.id, service.provider_id, COALESCE(service.category_id, ''),
		       service.title, service.rating::float8, service.reviews, service.duration_minutes,
		       service.price_cents, service.old_price_cents, service.image_url,
		       service.image_alignment, service.badge
		FROM services service
		JOIN providers provider ON provider.id = service.provider_id
		  AND provider.active AND provider.accepting_requests
		  AND provider.onboarding_status = 'approved' AND provider.owner_uid IS NOT NULL
		WHERE service.active AND service.deleted_at IS NULL
		  AND service.featured_position IS NOT NULL
		ORDER BY service.featured_position
		LIMIT 12`)
	if err != nil {
		return nil, fmt.Errorf("query recommended services: %w", err)
	}
	defer rows.Close()

	result := make([]domaincatalog.Service, 0, 12)
	for rows.Next() {
		var service domaincatalog.Service
		if err := rows.Scan(
			&service.ID, &service.ProviderID, &service.CategoryID, &service.Title, &service.Rating,
			&service.Reviews, &service.DurationMinutes, &service.PriceCents,
			&service.OldPriceCents, &service.ImageURL, &service.ImageAlignment,
			&service.Badge,
		); err != nil {
			return nil, fmt.Errorf("scan recommended service: %w", err)
		}
		result = append(result, service)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate recommended services: %w", err)
	}
	return result, nil
}
