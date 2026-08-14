package categories

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	domaincategories "github.com/vendlydigital/help/services/api/internal/domain/categories"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (r *Repository) ListPopular(ctx context.Context) ([]domaincategories.Category, error) {
	return r.list(ctx, 8)
}

func (r *Repository) ListActive(ctx context.Context) ([]domaincategories.Category, error) {
	return r.list(ctx, 100)
}

func (r *Repository) list(ctx context.Context, limit int) ([]domaincategories.Category, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, name, icon_key
		FROM categories
		WHERE active
		ORDER BY position
		LIMIT $1`, limit)
	if err != nil {
		return nil, fmt.Errorf("query categories: %w", err)
	}
	defer rows.Close()

	result := make([]domaincategories.Category, 0, limit)
	for rows.Next() {
		var category domaincategories.Category
		if err := rows.Scan(&category.ID, &category.Name, &category.IconKey); err != nil {
			return nil, fmt.Errorf("scan category: %w", err)
		}
		result = append(result, category)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate categories: %w", err)
	}
	return result, nil
}
