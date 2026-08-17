package chat

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

func (repository *Repository) CreateMedia(
	ctx context.Context,
	asset domainchat.MediaAsset,
) (domainchat.MediaAsset, error) {
	if _, err := repository.ConversationRecipients(ctx, asset.OwnerUID, asset.ConversationID); err != nil {
		return domainchat.MediaAsset{}, err
	}
	err := repository.pool.QueryRow(ctx, `
		INSERT INTO chat_media_assets (
			conversation_id, owner_uid, kind, storage_key, content_type, byte_size, duration_ms
		) VALUES ($1::uuid, $2, 'voice', $3, $4, $5, $6)
		RETURNING id::text, created_at`, asset.ConversationID, asset.OwnerUID,
		asset.StorageKey, asset.ContentType, asset.ByteSize, asset.DurationMS,
	).Scan(&asset.ID, &asset.CreatedAt)
	if err != nil {
		return domainchat.MediaAsset{}, fmt.Errorf("insert chat media: %w", err)
	}
	return asset, nil
}

func (repository *Repository) GetMedia(
	ctx context.Context,
	userID, mediaID string,
) (domainchat.MediaAsset, error) {
	var asset domainchat.MediaAsset
	err := repository.pool.QueryRow(ctx, `
		SELECT media.id::text, media.conversation_id::text, media.owner_uid,
		       media.storage_key, media.content_type, media.byte_size,
		       media.duration_ms, media.created_at
		FROM chat_media_assets media
		JOIN conversation_members member
		  ON member.conversation_id=media.conversation_id AND member.firebase_uid=$2
		WHERE media.id=$1::uuid`, mediaID, userID,
	).Scan(
		&asset.ID, &asset.ConversationID, &asset.OwnerUID, &asset.StorageKey,
		&asset.ContentType, &asset.ByteSize, &asset.DurationMS, &asset.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainchat.MediaAsset{}, domainchat.ErrMediaNotFound
	}
	if err != nil {
		return domainchat.MediaAsset{}, fmt.Errorf("read chat media: %w", err)
	}
	return asset, nil
}
