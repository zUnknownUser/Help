package chat

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"sort"

	"github.com/jackc/pgx/v5"

	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

func (repository *Repository) FindOrCreateDirect(
	ctx context.Context,
	userID, otherUserID string,
) (domainchat.Conversation, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainchat.Conversation{}, fmt.Errorf("begin direct conversation: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var profiles int
	if err := tx.QueryRow(ctx, `
		SELECT count(*) FROM user_profiles WHERE firebase_uid = ANY($1)`,
		[]string{userID, otherUserID},
	).Scan(&profiles); err != nil {
		return domainchat.Conversation{}, fmt.Errorf("check direct participants: %w", err)
	}
	if profiles != 2 {
		return domainchat.Conversation{}, domainchat.ErrRecipientNotFound
	}

	var conversation domainchat.Conversation
	key := directKey(userID, otherUserID)
	err = tx.QueryRow(ctx, `
		INSERT INTO conversations (direct_key, created_by)
		VALUES ($1, $2)
		ON CONFLICT (direct_key) DO UPDATE SET direct_key = EXCLUDED.direct_key
		RETURNING id::text, updated_at`, key, userID,
	).Scan(&conversation.ID, &conversation.UpdatedAt)
	if err != nil {
		return domainchat.Conversation{}, fmt.Errorf("upsert direct conversation: %w", err)
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO conversation_members (conversation_id, firebase_uid)
		VALUES ($1::uuid, $2), ($1::uuid, $3)
		ON CONFLICT DO NOTHING`, conversation.ID, userID, otherUserID); err != nil {
		return domainchat.Conversation{}, fmt.Errorf("add direct members: %w", err)
	}
	if err := tx.QueryRow(ctx, `
		SELECT display_name FROM user_profiles WHERE firebase_uid = $1`, otherUserID,
	).Scan(&conversation.OtherDisplayName); err != nil {
		return domainchat.Conversation{}, fmt.Errorf("read direct recipient: %w", err)
	}
	conversation.OtherUserID = otherUserID
	if err := tx.Commit(ctx); err != nil {
		return domainchat.Conversation{}, fmt.Errorf("commit direct conversation: %w", err)
	}
	return conversation, nil
}

func directKey(userID, otherUserID string) string {
	values := []string{userID, otherUserID}
	sort.Strings(values)
	digest := sha256.Sum256([]byte(values[0] + "\x00" + values[1]))
	return hex.EncodeToString(digest[:])
}

func mapChatError(err error) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return domainchat.ErrConversationNotFound
	}
	return err
}
