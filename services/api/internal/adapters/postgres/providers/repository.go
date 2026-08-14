package providers

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	domainproviders "github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (r *Repository) FindByIDs(ctx context.Context, ids []string) (map[string]domainproviders.Provider, error) {
	if len(ids) == 0 {
		return map[string]domainproviders.Provider{}, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, name, verified
		FROM providers
		WHERE active AND id = ANY($1)`, ids)
	if err != nil {
		return nil, fmt.Errorf("query providers: %w", err)
	}
	defer rows.Close()

	result := make(map[string]domainproviders.Provider, len(ids))
	for rows.Next() {
		var provider domainproviders.Provider
		if err := rows.Scan(&provider.ID, &provider.Name, &provider.Verified); err != nil {
			return nil, fmt.Errorf("scan provider: %w", err)
		}
		result[provider.ID] = provider
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate providers: %w", err)
	}
	return result, nil
}
