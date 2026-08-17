package providerworkspace

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/vendlydigital/help/services/api/internal/database"
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
	query, args, err := database.Query.Insert("services").Columns(
		"id", "provider_id", "category_id", "title", "description", "rating", "reviews",
		"duration_minutes", "price_cents", "old_price_cents", "image_url",
		"image_alignment", "badge", "active", "published_at",
	).Values(
		database.Expr("gen_random_uuid()::text"), providerID, nullableCategory(draft.CategoryID),
		draft.Title, draft.Description, 0, 0, draft.DurationMinutes, draft.PriceCents,
		draft.OldPriceCents, draft.ImageURL, 0, "", draft.Published, publishedAt(draft.Published),
	).Suffix("RETURNING " + managedServiceColumns).ToSql()
	if err != nil {
		return catalog.Service{}, fmt.Errorf("build create provider service: %w", err)
	}
	row := repository.pool.QueryRow(ctx, query, args...)
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
	update := database.Query.Update("services").SetMap(map[string]any{
		"category_id": nullableCategory(draft.CategoryID), "title": draft.Title,
		"description": draft.Description, "duration_minutes": draft.DurationMinutes,
		"price_cents": draft.PriceCents, "old_price_cents": draft.OldPriceCents,
		"image_url": draft.ImageURL, "active": draft.Published,
		"updated_at": database.Expr("now()"),
	})
	if draft.Published {
		update = update.Set("published_at", database.Expr("COALESCE(published_at, now())"))
	}
	query, args, err := update.Where("id = ?", serviceID).Where("provider_id = ?", providerID).
		Where("deleted_at IS NULL").Suffix("RETURNING " + managedServiceColumns).ToSql()
	if err != nil {
		return catalog.Service{}, fmt.Errorf("build update provider service: %w", err)
	}
	row := repository.pool.QueryRow(ctx, query, args...)
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
	update := database.Query.Update("services").Set("active", published).
		Set("updated_at", database.Expr("now()"))
	if published {
		update = update.Set("published_at", database.Expr("COALESCE(published_at, now())"))
	}
	query, args, err := update.Where("id = ?", serviceID).Where("provider_id = ?", providerID).
		Where("deleted_at IS NULL").Suffix("RETURNING " + managedServiceColumns).ToSql()
	if err != nil {
		return catalog.Service{}, fmt.Errorf("build publish provider service: %w", err)
	}
	row := repository.pool.QueryRow(ctx, query, args...)
	service, err := scanService(row)
	return service, mapServiceWriteError("publish provider service", err)
}

func (repository *Repository) DeleteService(ctx context.Context, uid, serviceID string) error {
	providerID, err := repository.authorizedProviderID(ctx, uid)
	if err != nil {
		return err
	}
	query, args, err := database.Query.Update("services").Set("active", false).
		Set("deleted_at", database.Expr("now()")).Set("updated_at", database.Expr("now()")).
		Where("id = ?", serviceID).Where("provider_id = ?", providerID).
		Where("deleted_at IS NULL").ToSql()
	if err != nil {
		return fmt.Errorf("build delete provider service: %w", err)
	}
	result, err := repository.pool.Exec(ctx, query, args...)
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
	query, args, err := database.Query.Update("providers").Set("accepting_requests", accepting).
		Set("updated_at", database.Expr("now()")).Where("owner_uid = ?", uid).ToSql()
	if err != nil {
		return fmt.Errorf("build provider availability: %w", err)
	}
	_, err = repository.pool.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("update provider availability: %w", err)
	}
	return nil
}

func (repository *Repository) authorizedProviderID(ctx context.Context, uid string) (string, error) {
	var id, status string
	var active bool
	query, args, buildErr := database.Query.Select("id", "onboarding_status", "active").
		From("providers").Where("owner_uid = ?", uid).ToSql()
	if buildErr != nil {
		return "", fmt.Errorf("build provider authorization: %w", buildErr)
	}
	err := repository.pool.QueryRow(ctx, query, args...).
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

func nullableCategory(value string) any {
	if value == "" {
		return nil
	}
	return value
}

func publishedAt(published bool) any {
	if published {
		return database.Expr("now()")
	}
	return nil
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
