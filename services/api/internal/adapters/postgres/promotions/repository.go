package promotions

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	domainpromotions "github.com/vendlydigital/help/services/api/internal/domain/promotions"
)

type Repository struct{ pool *pgxpool.Pool }

type featureRow struct {
	IconKey string `json:"icon_key"`
	Label   string `json:"label"`
}

type actionRow struct {
	ID      string `json:"id"`
	Label   string `json:"label"`
	IconKey string `json:"icon_key"`
	Style   string `json:"style"`
	Type    string `json:"type"`
	Target  string `json:"target"`
}

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (r *Repository) ListActive(ctx context.Context) ([]domainpromotions.Promotion, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT p.id, p.eyebrow, p.title, p.image_url,
		       COALESCE((
		           SELECT jsonb_agg(jsonb_build_object('icon_key', f.icon_key, 'label', f.label) ORDER BY f.position)
		           FROM (
		               SELECT icon_key, label, position
		               FROM promotion_features
		               WHERE promotion_id = p.id
		               ORDER BY position
		               LIMIT 4
		           ) f
		       ), '[]'::jsonb),
		       COALESCE((
		           SELECT jsonb_agg(jsonb_build_object('id', a.id, 'label', a.label, 'icon_key', a.icon_key, 'style', a.style, 'type', a.action_type, 'target', COALESCE(a.action_target, '')) ORDER BY a.position)
		           FROM (
		               SELECT id, label, icon_key, style, action_type, action_target, position
		               FROM promotion_actions
		               WHERE promotion_id = p.id AND action_type <> 'none'
		               ORDER BY position
		               LIMIT 2
		           ) a
		       ), '[]'::jsonb)
		FROM promotions p
		WHERE p.active
		  AND (p.starts_at IS NULL OR p.starts_at <= now())
		  AND (p.ends_at IS NULL OR p.ends_at > now())
		ORDER BY p.position
		LIMIT 5`)
	if err != nil {
		return nil, fmt.Errorf("query promotions: %w", err)
	}
	defer rows.Close()

	result := make([]domainpromotions.Promotion, 0, 5)
	for rows.Next() {
		var promotion domainpromotions.Promotion
		var featuresJSON, actionsJSON []byte
		if err := rows.Scan(
			&promotion.ID, &promotion.Eyebrow, &promotion.Title,
			&promotion.ImageURL, &featuresJSON, &actionsJSON,
		); err != nil {
			return nil, fmt.Errorf("scan promotion: %w", err)
		}
		var features []featureRow
		if err := json.Unmarshal(featuresJSON, &features); err != nil {
			return nil, fmt.Errorf("decode promotion features: %w", err)
		}
		for _, feature := range features {
			promotion.Features = append(promotion.Features, domainpromotions.Feature(feature))
		}
		var actions []actionRow
		if err := json.Unmarshal(actionsJSON, &actions); err != nil {
			return nil, fmt.Errorf("decode promotion actions: %w", err)
		}
		for _, action := range actions {
			promotion.Actions = append(promotion.Actions, domainpromotions.Action(action))
		}
		result = append(result, promotion)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate promotions: %w", err)
	}
	return result, nil
}
