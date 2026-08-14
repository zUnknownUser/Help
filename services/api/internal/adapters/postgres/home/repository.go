package home

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
)

type Repository struct{ pool *pgxpool.Pool }

type benefitRow struct {
	ID      string `json:"id"`
	Label   string `json:"label"`
	IconKey string `json:"icon_key"`
}

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (r *Repository) GetFrame(ctx context.Context) (domainhome.Frame, error) {
	var frame domainhome.Frame
	var benefitsJSON []byte
	err := r.pool.QueryRow(ctx, `
		SELECT c.search_placeholder,
		       COALESCE(c.categories_title, ''), COALESCE(c.recommendations_title, ''),
		       COALESCE((
		           SELECT jsonb_agg(jsonb_build_object('id', b.id, 'label', b.label, 'icon_key', b.icon_key) ORDER BY b.position)
		           FROM (
		               SELECT id, label, icon_key, position
		               FROM home_benefits
		               WHERE active
		               ORDER BY position
		               LIMIT 4
		           ) b
		       ), '[]'::jsonb)
		FROM home_configuration c
		WHERE c.id = 1`).Scan(
		&frame.SearchPlaceholder,
		&frame.CategoriesTitle,
		&frame.RecommendationsTitle,
		&benefitsJSON,
	)
	if err == pgx.ErrNoRows {
		return domainhome.Frame{}, nil
	}
	if err != nil {
		return domainhome.Frame{}, fmt.Errorf("query home frame: %w", err)
	}
	var benefits []benefitRow
	if err := json.Unmarshal(benefitsJSON, &benefits); err != nil {
		return domainhome.Frame{}, fmt.Errorf("decode home benefits: %w", err)
	}
	for _, benefit := range benefits {
		frame.Benefits = append(frame.Benefits, domainhome.Benefit(benefit))
	}
	return frame, nil
}
