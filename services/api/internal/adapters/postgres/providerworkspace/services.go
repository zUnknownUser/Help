package providerworkspace

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

const managedServiceColumns = `
	id, provider_id, COALESCE(category_id, ''), title, description,
	rating::float8, reviews, duration_minutes, price_cents, old_price_cents,
	image_url, image_alignment, badge, active, published_at, created_at, updated_at`

func (repository *Repository) CreateService(
	ctx context.Context,
	uid string,
	draft catalog.ServiceDraft,
) (catalog.Service, error) {
	providerID, err := repository.authorizedProviderID(ctx, uid)
	if err != nil {
		return catalog.Service{}, err
	}
	row := repository.pool.QueryRow(ctx, `
		INSERT INTO services (
			id, provider_id, category_id, title, description, rating, reviews,
			duration_minutes, price_cents, old_price_cents, image_url,
			image_alignment, badge, active, published_at
		) VALUES (
			gen_random_uuid()::text, $1, NULLIF($2, ''), $3, $4, 0, 0,
			$5, $6, $6, $7, 0, '', $8,
			CASE WHEN $8 THEN now() ELSE NULL END
		)
		RETURNING `+managedServiceColumns,
		providerID, draft.CategoryID, draft.Title, draft.Description,
		draft.DurationMinutes, draft.PriceCents, draft.ImageURL, draft.Published,
	)
	service, err := scanService(row)
	return service, mapServiceWriteError("create provider service", err)
}

func (repository *Repository) UpdateService(
	ctx context.Context,
	uid, serviceID string,
	draft catalog.ServiceDraft,
) (catalog.Service, error) {
	providerID, err := repository.authorizedProviderID(ctx, uid)
	if err != nil {
		return catalog.Service{}, err
	}
	row := repository.pool.QueryRow(ctx, `
		UPDATE services SET
			category_id = NULLIF($3, ''), title = $4, description = $5,
			duration_minutes = $6, price_cents = $7, old_price_cents = $7,
			image_url = $8, active = $9,
			published_at = CASE WHEN $9 THEN COALESCE(published_at, now()) ELSE published_at END,
			updated_at = now()
		WHERE id = $1 AND provider_id = $2 AND deleted_at IS NULL
		RETURNING `+managedServiceColumns,
		serviceID, providerID, draft.CategoryID, draft.Title, draft.Description,
		draft.DurationMinutes, draft.PriceCents, draft.ImageURL, draft.Published,
	)
	service, err := scanService(row)
	return service, mapServiceWriteError("update provider service", err)
}

func (repository *Repository) SetServicePublished(
	ctx context.Context,
	uid, serviceID string,
	published bool,
) (catalog.Service, error) {
	providerID, err := repository.authorizedProviderID(ctx, uid)
	if err != nil {
		return catalog.Service{}, err
	}
	row := repository.pool.QueryRow(ctx, `
		UPDATE services SET
			active = $3,
			published_at = CASE WHEN $3 THEN COALESCE(published_at, now()) ELSE published_at END,
			updated_at = now()
		WHERE id = $1 AND provider_id = $2 AND deleted_at IS NULL
		RETURNING `+managedServiceColumns, serviceID, providerID, published)
	service, err := scanService(row)
	return service, mapServiceWriteError("publish provider service", err)
}

func (repository *Repository) DeleteService(ctx context.Context, uid, serviceID string) error {
	providerID, err := repository.authorizedProviderID(ctx, uid)
	if err != nil {
		return err
	}
	result, err := repository.pool.Exec(ctx, `
		UPDATE services SET active = false, deleted_at = now(), updated_at = now()
		WHERE id = $1 AND provider_id = $2 AND deleted_at IS NULL`, serviceID, providerID)
	if err != nil {
		return fmt.Errorf("delete provider service: %w", err)
	}
	if result.RowsAffected() == 0 {
		return providers.ErrServiceNotFound
	}
	return nil
}

func (repository *Repository) SetAcceptingRequests(ctx context.Context, uid string, accepting bool) error {
	if _, err := repository.authorizedProviderID(ctx, uid); err != nil {
		return err
	}
	_, err := repository.pool.Exec(ctx, `
		UPDATE providers SET accepting_requests = $2, updated_at = now()
		WHERE owner_uid = $1`, uid, accepting)
	if err != nil {
		return fmt.Errorf("update provider availability: %w", err)
	}
	return nil
}

func (repository *Repository) authorizedProviderID(ctx context.Context, uid string) (string, error) {
	var id, status string
	var active bool
	err := repository.pool.QueryRow(ctx, `
		SELECT id, onboarding_status, active FROM providers WHERE owner_uid = $1`, uid).
		Scan(&id, &status, &active)
	if err == pgx.ErrNoRows {
		return "", providers.ErrWorkspaceNotFound
	}
	if err != nil {
		return "", fmt.Errorf("query provider authorization: %w", err)
	}
	if status != "approved" || !active {
		return "", providers.ErrProviderUnavailable
	}
	return id, nil
}

func mapServiceWriteError(operation string, err error) error {
	if err == nil {
		return nil
	}
	if err == pgx.ErrNoRows {
		return providers.ErrServiceNotFound
	}
	var postgresError *pgconn.PgError
	if errors.As(err, &postgresError) && postgresError.Code == "23503" {
		return catalog.ErrInvalidServiceCategory
	}
	return fmt.Errorf("%s: %w", operation, err)
}
