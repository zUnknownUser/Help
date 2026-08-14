package devices

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/vendlydigital/help/services/api/internal/domain/devices"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (repository *Repository) Upsert(ctx context.Context, installation devices.Installation) error {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin device installation: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`, installation.Token); err != nil {
		return fmt.Errorf("lock device token: %w", err)
	}
	if _, err = tx.Exec(ctx, `DELETE FROM device_installations
		WHERE fcm_token = $1 AND installation_id <> $2::uuid`, installation.Token, installation.ID); err != nil {
		return fmt.Errorf("move device token: %w", err)
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO device_installations (installation_id, firebase_uid, platform, fcm_token)
		VALUES ($1::uuid, $2, $3, $4)
		ON CONFLICT (installation_id) DO UPDATE SET
		  firebase_uid = EXCLUDED.firebase_uid,
		  platform = EXCLUDED.platform,
		  fcm_token = EXCLUDED.fcm_token,
		  enabled = true,
		  last_seen_at = now()`, installation.ID, installation.UserID, installation.Platform, installation.Token)
	if err != nil {
		return fmt.Errorf("upsert device installation: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit device installation: %w", err)
	}
	return nil
}

func (repository *Repository) Disable(ctx context.Context, userID, installationID string) error {
	_, err := repository.pool.Exec(ctx, `
		UPDATE device_installations SET enabled = false, last_seen_at = now()
		WHERE firebase_uid = $1 AND installation_id = $2::uuid`, userID, installationID)
	if err != nil {
		return fmt.Errorf("disable device installation: %w", err)
	}
	return nil
}

func (repository *Repository) Tokens(ctx context.Context, userID string) ([]string, error) {
	rows, err := repository.pool.Query(ctx, `
		SELECT fcm_token FROM device_installations
		WHERE firebase_uid = $1 AND enabled
		ORDER BY last_seen_at DESC`, userID)
	if err != nil {
		return nil, fmt.Errorf("query device tokens: %w", err)
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, fmt.Errorf("scan device token: %w", err)
		}
		tokens = append(tokens, token)
	}
	return tokens, rows.Err()
}

func (repository *Repository) DisableTokens(ctx context.Context, tokens []string) error {
	if len(tokens) == 0 {
		return nil
	}
	_, err := repository.pool.Exec(ctx, `
		UPDATE device_installations SET enabled = false, last_seen_at = now()
		WHERE fcm_token = ANY($1)`, tokens)
	if err != nil {
		return fmt.Errorf("disable invalid device tokens: %w", err)
	}
	return nil
}
