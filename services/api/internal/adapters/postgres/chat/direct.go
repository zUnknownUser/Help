package chat

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

func (repository *Repository) FindOrCreateDirect(
	ctx context.Context,
	userID, otherUserID string,
) (domainchat.Conversation, []string, bool, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainchat.Conversation{}, nil, false, fmt.Errorf("begin direct conversation: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	key := directKey(userID, otherUserID)
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`, key); err != nil {
		return domainchat.Conversation{}, nil, false, fmt.Errorf("lock direct conversation: %w", err)
	}
	var profiles int
	if err := tx.QueryRow(ctx, `SELECT count(*) FROM user_profiles WHERE firebase_uid = ANY($1)`,
		[]string{userID, otherUserID},
	).Scan(&profiles); err != nil {
		return domainchat.Conversation{}, nil, false, fmt.Errorf("check direct participants: %w", err)
	}
	if profiles != 2 {
		return domainchat.Conversation{}, nil, false, domainchat.ErrRecipientNotFound
	}

	linked, err := authorizeDirect(ctx, tx, key, userID, otherUserID)
	if err != nil {
		return domainchat.Conversation{}, nil, false, err
	}
	conversation, requestedBy, changed, err := findOrCreateConversation(
		ctx, tx, key, userID, linked,
	)
	if err != nil {
		return domainchat.Conversation{}, nil, false, err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO conversation_members (conversation_id, firebase_uid)
		VALUES ($1::uuid, $2), ($1::uuid, $3)
		ON CONFLICT DO NOTHING`, conversation.ID, userID, otherUserID); err != nil {
		return domainchat.Conversation{}, nil, false, fmt.Errorf("add direct members: %w", err)
	}
	if err := hydrateDirectRecipient(ctx, tx, &conversation, userID, otherUserID, requestedBy); err != nil {
		return domainchat.Conversation{}, nil, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domainchat.Conversation{}, nil, false, fmt.Errorf("commit direct conversation: %w", err)
	}
	return conversation, []string{otherUserID}, changed, nil
}

func (repository *Repository) DecideConversation(
	ctx context.Context,
	userID, conversationID string,
	accept bool,
) (domainchat.Conversation, []string, bool, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainchat.Conversation{}, nil, false, fmt.Errorf("begin conversation decision: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var conversation domainchat.Conversation
	var requestedBy string
	var lastSeenAt *time.Time
	err = tx.QueryRow(ctx, `
		SELECT c.id::text, c.status, c.requested_by, c.updated_at,
		       other.firebase_uid, profile.display_name,
		       CASE WHEN profile.last_seen_visibility='nobody' THEN NULL ELSE profile.last_seen_at END,
		       profile.show_online
		FROM conversations c
		JOIN conversation_members member
		  ON member.conversation_id = c.id AND member.firebase_uid = $2
		JOIN conversation_members other
		  ON other.conversation_id = c.id AND other.firebase_uid <> $2
		JOIN user_profiles profile ON profile.firebase_uid = other.firebase_uid
		WHERE c.id = $1::uuid
		FOR UPDATE OF c`, conversationID, userID,
	).Scan(
		&conversation.ID, &conversation.Status, &requestedBy, &conversation.UpdatedAt,
		&conversation.OtherUserID, &conversation.OtherDisplayName, &lastSeenAt,
		&conversation.OtherCanShowOnline,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainchat.Conversation{}, nil, false, domainchat.ErrForbidden
	}
	if err != nil {
		return domainchat.Conversation{}, nil, false, fmt.Errorf("load conversation decision: %w", err)
	}
	if requestedBy == userID {
		return domainchat.Conversation{}, nil, false, domainchat.ErrForbidden
	}
	target := domainchat.ConversationDeclined
	if accept {
		target = domainchat.ConversationAccepted
	}
	changed := conversation.Status == domainchat.ConversationPending
	if changed {
		err = tx.QueryRow(ctx, `UPDATE conversations
			SET status = $2, responded_at = now(), updated_at = now()
			WHERE id = $1::uuid RETURNING status, updated_at`, conversationID, target,
		).Scan(&conversation.Status, &conversation.UpdatedAt)
		if err != nil {
			return domainchat.Conversation{}, nil, false, fmt.Errorf("save conversation decision: %w", err)
		}
	}
	conversation.RequestedByMe = false
	if conversation.Status == domainchat.ConversationAccepted {
		conversation.OtherLastSeenAt = lastSeenAt
	}
	if err := tx.Commit(ctx); err != nil {
		return domainchat.Conversation{}, nil, false, fmt.Errorf("commit conversation decision: %w", err)
	}
	return conversation, []string{conversation.OtherUserID}, changed, nil
}

func findOrCreateConversation(
	ctx context.Context,
	tx pgx.Tx,
	key, userID string,
	linked bool,
) (domainchat.Conversation, string, bool, error) {
	var conversation domainchat.Conversation
	var requestedBy string
	err := tx.QueryRow(ctx, `SELECT id::text, updated_at, status, requested_by
		FROM conversations WHERE direct_key = $1`, key,
	).Scan(&conversation.ID, &conversation.UpdatedAt, &conversation.Status, &requestedBy)
	if errors.Is(err, pgx.ErrNoRows) {
		status := domainchat.ConversationPending
		if linked {
			status = domainchat.ConversationAccepted
		}
		err = tx.QueryRow(ctx, `INSERT INTO conversations
			(direct_key, created_by, status, requested_by)
			VALUES ($1, $2, $3, $2)
			RETURNING id::text, updated_at, status, requested_by`, key, userID, status,
		).Scan(&conversation.ID, &conversation.UpdatedAt, &conversation.Status, &requestedBy)
		return conversation, requestedBy, true, err
	}
	if err != nil {
		return domainchat.Conversation{}, "", false, fmt.Errorf("find direct conversation: %w", err)
	}
	if linked && conversation.Status != domainchat.ConversationAccepted {
		err = tx.QueryRow(ctx, `UPDATE conversations
			SET status = 'accepted', responded_at = now(), updated_at = now()
			WHERE id = $1::uuid RETURNING status, updated_at`, conversation.ID,
		).Scan(&conversation.Status, &conversation.UpdatedAt)
		return conversation, requestedBy, true, err
	}
	return conversation, requestedBy, false, nil
}

func hydrateDirectRecipient(
	ctx context.Context,
	tx pgx.Tx,
	conversation *domainchat.Conversation,
	userID, otherUserID, requestedBy string,
) error {
	conversation.OtherUserID = otherUserID
	conversation.RequestedByMe = requestedBy == userID
	var lastSeenAt *time.Time
	if err := tx.QueryRow(ctx, `SELECT display_name,
		CASE WHEN last_seen_visibility='nobody' THEN NULL ELSE last_seen_at END, show_online
		FROM user_profiles WHERE firebase_uid = $1`, otherUserID,
	).Scan(&conversation.OtherDisplayName, &lastSeenAt, &conversation.OtherCanShowOnline); err != nil {
		return fmt.Errorf("read direct recipient: %w", err)
	}
	if conversation.Status == domainchat.ConversationAccepted {
		conversation.OtherLastSeenAt = lastSeenAt
	}
	return nil
}

func authorizeDirect(
	ctx context.Context,
	tx pgx.Tx,
	key, userID, otherUserID string,
) (bool, error) {
	var existing, linked, eligibleNewRequest bool
	query, args, buildErr := database.Query.Select().
		Column("EXISTS(SELECT 1 FROM conversations WHERE direct_key = ?)", key).
		Column(`EXISTS(
			SELECT 1 FROM service_requests request
			JOIN providers provider ON provider.id = request.provider_id
			WHERE ((request.customer_uid = ? AND provider.owner_uid = ?)
			   OR (request.customer_uid = ? AND provider.owner_uid = ?))
			  AND request.status IN ('pending','accepted','in_progress','completed','no_show')
		)`, userID, otherUserID, otherUserID, userID).
		Column(`EXISTS(
			SELECT 1
			FROM user_profiles requester
			JOIN providers recipient ON recipient.owner_uid = ?
			JOIN user_profiles recipient_profile ON recipient_profile.firebase_uid=recipient.owner_uid
			WHERE requester.firebase_uid = ?
			  AND requester.active_role = 'customer'
			  AND recipient_profile.allow_conversation_requests
			  AND recipient.active
			  AND recipient.accepting_requests
			  AND recipient.onboarding_status = 'approved'
		)`, otherUserID, userID).ToSql()
	if buildErr != nil {
		return false, fmt.Errorf("build direct conversation authorization: %w", buildErr)
	}
	err := tx.QueryRow(ctx, query, args...).Scan(&existing, &linked, &eligibleNewRequest)
	if err != nil {
		return false, fmt.Errorf("authorize direct conversation: %w", err)
	}
	if !existing && !linked && !eligibleNewRequest {
		return false, domainchat.ErrForbidden
	}
	return linked, nil
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
