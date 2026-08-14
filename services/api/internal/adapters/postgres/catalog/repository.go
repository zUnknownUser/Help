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
		SELECT id, provider_id, title, rating::float8, reviews, duration_minutes,
		       price_cents, old_price_cents, image_url, image_alignment, badge
		FROM services
		WHERE active AND featured_position IS NOT NULL
		ORDER BY featured_position
		LIMIT 12`)
	if err != nil {
		return nil, fmt.Errorf("query recommended services: %w", err)
	}
	defer rows.Close()

	result := make([]domaincatalog.Service, 0, 12)
	for rows.Next() {
		var service domaincatalog.Service
		if err := rows.Scan(
			&service.ID, &service.ProviderID, &service.Title, &service.Rating,
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
