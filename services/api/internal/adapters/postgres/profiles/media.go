package profiles

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/database"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

func (repository *Repository) SetAvatar(
	ctx context.Context,
	uid, storageKey, contentType string,
) (string, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return "", fmt.Errorf("begin avatar update: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var oldKey *string
	// Load the previous opaque key before replacing it so storage cleanup can be performed safely.
	selectQuery, selectArgs, err := database.Query.Select("avatar_storage_key").
		From("user_profiles").Where("firebase_uid = ?", uid).Suffix("FOR UPDATE").ToSql()
	if err != nil {
		return "", fmt.Errorf("build previous avatar query: %w", err)
	}
	if err := tx.QueryRow(ctx, selectQuery, selectArgs...).Scan(&oldKey); errors.Is(err, pgx.ErrNoRows) {
		return "", domainprofiles.ErrProfileNotFound
	} else if err != nil {
		return "", fmt.Errorf("load previous avatar: %w", err)
	}
	query, args, err := database.Query.Update("user_profiles").
		Set("avatar_storage_key", storageKey).Set("avatar_content_type", contentType).
		Set("updated_at", database.Expr("now()")).Where("firebase_uid = ?", uid).ToSql()
	if err != nil {
		return "", fmt.Errorf("build avatar update: %w", err)
	}
	if _, err := tx.Exec(ctx, query, args...); err != nil {
		return "", fmt.Errorf("update avatar: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return "", fmt.Errorf("commit avatar update: %w", err)
	}
	if oldKey == nil {
		return "", nil
	}
	return *oldKey, nil
}

func (repository *Repository) GetAvatar(ctx context.Context, viewerUID, targetUID string) (ports.ProfileMedia, error) {
	query, args, err := database.Query.Select("avatar_storage_key", "avatar_content_type").
		From("user_profiles target").Where("target.firebase_uid = ?", targetUID).
		Where("target.avatar_storage_key IS NOT NULL").Where(`(
			target.firebase_uid = ? OR target.photo_visibility = 'everyone' OR
			(target.photo_visibility = 'conversations' AND EXISTS(
				SELECT 1 FROM conversations conversation
				JOIN conversation_members viewer ON viewer.conversation_id=conversation.id AND viewer.firebase_uid=?
				JOIN conversation_members peer ON peer.conversation_id=conversation.id AND peer.firebase_uid=target.firebase_uid
				WHERE conversation.status='accepted'
			))
		)`, viewerUID, viewerUID).ToSql()
	if err != nil {
		return ports.ProfileMedia{}, fmt.Errorf("build avatar query: %w", err)
	}
	var media ports.ProfileMedia
	err = repository.pool.QueryRow(ctx, query, args...).Scan(&media.StorageKey, &media.ContentType)
	if errors.Is(err, pgx.ErrNoRows) {
		return ports.ProfileMedia{}, domainprofiles.ErrProfileNotFound
	}
	if err != nil {
		return ports.ProfileMedia{}, fmt.Errorf("query avatar: %w", err)
	}
	return media, nil
}

func (repository *Repository) AddPortfolio(
	ctx context.Context,
	uid, storageKey, contentType, caption string,
) (domainprofiles.PortfolioItem, error) {
	providerQuery, providerArgs, err := database.Query.Select("id").From("providers").
		Where("owner_uid = ?", uid).ToSql()
	if err != nil {
		return domainprofiles.PortfolioItem{}, fmt.Errorf("build portfolio owner query: %w", err)
	}
	var providerID string
	if err := repository.pool.QueryRow(ctx, providerQuery, providerArgs...).Scan(&providerID); errors.Is(err, pgx.ErrNoRows) {
		return domainprofiles.PortfolioItem{}, domainprofiles.ErrProfileNotFound
	} else if err != nil {
		return domainprofiles.PortfolioItem{}, fmt.Errorf("query portfolio owner: %w", err)
	}

	query, args, err := database.Query.Insert("provider_portfolio_items").
		Columns("provider_id", "storage_key", "content_type", "caption", "position").
		Values(providerID, storageKey, contentType, caption,
			database.Expr("(SELECT COALESCE(max(position),-1)+1 FROM provider_portfolio_items WHERE provider_id=?)", providerID)).
		Suffix("RETURNING id::text, caption, position").ToSql()
	if err != nil {
		return domainprofiles.PortfolioItem{}, fmt.Errorf("build portfolio insert: %w", err)
	}
	var item domainprofiles.PortfolioItem
	if err := repository.pool.QueryRow(ctx, query, args...).Scan(&item.ID, &item.Caption, &item.Position); err != nil {
		return domainprofiles.PortfolioItem{}, fmt.Errorf("insert portfolio: %w", err)
	}
	return item, nil
}

func (repository *Repository) GetPortfolio(ctx context.Context, id string) (ports.ProfileMedia, error) {
	query, args, err := database.Query.Select("storage_key", "content_type").
		From("provider_portfolio_items").Where("id = ?::uuid", id).ToSql()
	if err != nil {
		return ports.ProfileMedia{}, fmt.Errorf("build portfolio media query: %w", err)
	}
	var media ports.ProfileMedia
	err = repository.pool.QueryRow(ctx, query, args...).Scan(&media.StorageKey, &media.ContentType)
	if errors.Is(err, pgx.ErrNoRows) {
		return ports.ProfileMedia{}, domainprofiles.ErrProfileNotFound
	}
	if err != nil {
		return ports.ProfileMedia{}, fmt.Errorf("query portfolio media: %w", err)
	}
	return media, nil
}

func (repository *Repository) DeletePortfolio(ctx context.Context, uid, id string) (string, error) {
	ownerQuery, ownerArgs, err := database.Query.Select("id").From("providers").Where("owner_uid = ?", uid).ToSql()
	if err != nil {
		return "", fmt.Errorf("build portfolio owner query: %w", err)
	}
	var providerID string
	if err := repository.pool.QueryRow(ctx, ownerQuery, ownerArgs...).Scan(&providerID); errors.Is(err, pgx.ErrNoRows) {
		return "", domainprofiles.ErrProfileNotFound
	} else if err != nil {
		return "", fmt.Errorf("query portfolio owner: %w", err)
	}
	query, args, err := database.Query.Delete("provider_portfolio_items").
		Where("provider_id = ?", providerID).Where("id = ?::uuid", id).
		Suffix("RETURNING storage_key").ToSql()
	if err != nil {
		return "", fmt.Errorf("build portfolio delete: %w", err)
	}
	var storageKey string
	err = repository.pool.QueryRow(ctx, query, args...).Scan(&storageKey)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", domainprofiles.ErrProfileNotFound
	}
	if err != nil {
		return "", fmt.Errorf("delete portfolio: %w", err)
	}
	return storageKey, nil
}
