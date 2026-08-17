package chat

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/vendlydigital/help/services/api/internal/database"

	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

func (repository *Repository) AdvanceDelivered(
	ctx context.Context,
	userID, conversationID string,
	sequence int64,
) ([]string, error) {
	return repository.advanceReceipt(ctx, userID, conversationID, sequence, false)
}

func (repository *Repository) AdvanceRead(
	ctx context.Context,
	userID, conversationID string,
	sequence int64,
) ([]string, error) {
	return repository.advanceReceipt(ctx, userID, conversationID, sequence, true)
}

func (repository *Repository) advanceReceipt(
	ctx context.Context,
	userID, conversationID string,
	sequence int64,
	read bool,
) ([]string, error) {
	if sequence < 1 {
		return nil, domainchat.ErrInvalidMessage
	}
	setClause := `last_delivered_sequence = GREATEST(
		last_delivered_sequence, LEAST($3, conversation.last_sequence)
	)`
	if read {
		setClause = `last_read_sequence = GREATEST(
			last_read_sequence, LEAST($3, conversation.last_sequence)
		), last_delivered_sequence = GREATEST(
			last_delivered_sequence, LEAST($3, conversation.last_sequence)
		)`
	}
	command, err := repository.pool.Exec(ctx, `
		UPDATE conversation_members member
		SET `+setClause+`
		FROM conversations conversation
		WHERE member.conversation_id = conversation.id
		  AND member.conversation_id = $1::uuid
		  AND member.firebase_uid = $2
		  AND conversation.status = 'accepted'`, conversationID, userID, sequence)
	if err != nil {
		return nil, fmt.Errorf("advance chat receipt: %w", err)
	}
	if command.RowsAffected() == 0 {
		return nil, conversationAccessError(
			ctx, repository.pool, userID, conversationID,
		)
	}
	return repository.ConversationRecipients(ctx, userID, conversationID)
}

func (repository *Repository) ConversationRecipients(
	ctx context.Context,
	userID, conversationID string,
) ([]string, error) {
	return conversationRecipients(ctx, repository.pool, userID, conversationID)
}

type rowsQuerier interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
	QueryRow(context.Context, string, ...any) pgx.Row
}

func conversationRecipients(
	ctx context.Context,
	query rowsQuerier,
	userID, conversationID string,
) ([]string, error) {
	rows, err := query.Query(ctx, `
		SELECT recipient.firebase_uid
		FROM conversation_members member
		JOIN conversations conversation
		  ON conversation.id = member.conversation_id
		 AND conversation.status = 'accepted'
		JOIN conversation_members recipient
		  ON recipient.conversation_id = member.conversation_id
		 AND recipient.firebase_uid <> member.firebase_uid
		WHERE member.conversation_id = $1::uuid AND member.firebase_uid = $2`,
		conversationID, userID)
	if err != nil {
		return nil, fmt.Errorf("query conversation recipients: %w", err)
	}
	defer rows.Close()
	var recipients []string
	for rows.Next() {
		var recipient string
		if err := rows.Scan(&recipient); err != nil {
			return nil, fmt.Errorf("scan conversation recipient: %w", err)
		}
		recipients = append(recipients, recipient)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate conversation recipients: %w", err)
	}
	if recipients == nil {
		return nil, conversationAccessError(ctx, query, userID, conversationID)
	}
	return recipients, nil
}

func conversationAccessError(
	ctx context.Context,
	query interface {
		QueryRow(context.Context, string, ...any) pgx.Row
	},
	userID, conversationID string,
) error {
	var status domainchat.ConversationStatus
	err := query.QueryRow(ctx, `
		SELECT conversation.status
		FROM conversations conversation
		JOIN conversation_members member ON member.conversation_id = conversation.id
		WHERE conversation.id = $1::uuid AND member.firebase_uid = $2`,
		conversationID, userID,
	).Scan(&status)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainchat.ErrForbidden
	}
	if err != nil {
		return fmt.Errorf("check conversation access: %w", err)
	}
	if status != domainchat.ConversationAccepted {
		return domainchat.ErrConversationPending
	}
	return domainchat.ErrForbidden
}

func (repository *Repository) requireMember(ctx context.Context, userID, conversationID string) error {
	var exists bool
	err := repository.pool.QueryRow(ctx, `
		SELECT EXISTS(
		  SELECT 1 FROM conversation_members
		  WHERE conversation_id = $1::uuid AND firebase_uid = $2
		)`, conversationID, userID).Scan(&exists)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("check conversation membership: %w", err)
	}
	if !exists {
		return domainchat.ErrForbidden
	}
	return nil
}

func (repository *Repository) UpdateLastSeen(
	ctx context.Context,
	userID string,
) (time.Time, error) {
	var lastSeen time.Time
	err := repository.pool.QueryRow(ctx, `UPDATE user_profiles
		SET last_seen_at = now(), updated_at = now()
		WHERE firebase_uid = $1
		RETURNING last_seen_at`, userID).Scan(&lastSeen)
	if errors.Is(err, pgx.ErrNoRows) {
		return time.Time{}, domainchat.ErrForbidden
	}
	if err != nil {
		return time.Time{}, fmt.Errorf("update chat last seen: %w", err)
	}
	return lastSeen, nil
}

func (repository *Repository) UserPeerPresences(
	ctx context.Context,
	userID string,
) ([]domainchat.Presence, error) {
	query, args, buildErr := database.Query.Select("DISTINCT peer.firebase_uid",
		"CASE WHEN profile.last_seen_visibility='nobody' THEN NULL ELSE profile.last_seen_at END",
		"profile.show_online").From("conversation_members member").
		Join("conversation_members peer ON peer.conversation_id=member.conversation_id AND peer.firebase_uid<>member.firebase_uid").
		Join("user_profiles profile ON profile.firebase_uid=peer.firebase_uid").
		Join("conversations conversation ON conversation.id=member.conversation_id AND conversation.status='accepted'").
		Where("member.firebase_uid = ?", userID).ToSql()
	if buildErr != nil {
		return nil, fmt.Errorf("build chat peers: %w", buildErr)
	}
	rows, err := repository.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("query chat peers: %w", err)
	}
	defer rows.Close()
	var peers []domainchat.Presence
	for rows.Next() {
		var peer domainchat.Presence
		if err := rows.Scan(&peer.UserID, &peer.LastSeenAt, &peer.CanShowOnline); err != nil {
			return nil, err
		}
		peers = append(peers, peer)
	}
	return peers, rows.Err()
}

func (repository *Repository) PresencePolicy(ctx context.Context, userID string) (domainchat.PresencePolicy, error) {
	query, args, err := database.Query.Select("show_online", "last_seen_visibility <> 'nobody'").
		From("user_profiles").Where("firebase_uid = ?", userID).ToSql()
	if err != nil {
		return domainchat.PresencePolicy{}, fmt.Errorf("build presence policy: %w", err)
	}
	var policy domainchat.PresencePolicy
	err = repository.pool.QueryRow(ctx, query, args...).Scan(&policy.ShowOnline, &policy.ShowLastSeen)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainchat.PresencePolicy{}, domainchat.ErrForbidden
	}
	if err != nil {
		return domainchat.PresencePolicy{}, fmt.Errorf("query presence policy: %w", err)
	}
	return policy, nil
}
