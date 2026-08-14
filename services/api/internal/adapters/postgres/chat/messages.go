package chat

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

const messageColumns = `
	m.id::text, m.client_id::text, m.conversation_id::text, m.sender_uid,
	m.content, m.sequence, m.created_at,
	CASE
	  WHEN NOT EXISTS (
	    SELECT 1 FROM conversation_members receipt
	    WHERE receipt.conversation_id = m.conversation_id
	      AND receipt.firebase_uid <> m.sender_uid
	      AND receipt.last_read_sequence < m.sequence
	  ) THEN 'read'
	  WHEN NOT EXISTS (
	    SELECT 1 FROM conversation_members receipt
	    WHERE receipt.conversation_id = m.conversation_id
	      AND receipt.firebase_uid <> m.sender_uid
	      AND receipt.last_delivered_sequence < m.sequence
	  ) THEN 'delivered'
	  ELSE 'sent'
	END`

func (repository *Repository) ListMessages(
	ctx context.Context,
	userID, conversationID string,
	limit int,
	before, after *int64,
) (domainchat.MessagePage, error) {
	if err := repository.requireMember(ctx, userID, conversationID); err != nil {
		return domainchat.MessagePage{}, err
	}
	rows, err := repository.pool.Query(ctx, `SELECT `+messageColumns+`
		FROM chat_messages m
		WHERE m.conversation_id = $1::uuid
		  AND ($2::bigint IS NULL OR m.sequence < $2)
		  AND ($3::bigint IS NULL OR m.sequence > $3)
		ORDER BY m.sequence DESC
		LIMIT $4`, conversationID, before, after, limit+1)
	if err != nil {
		return domainchat.MessagePage{}, fmt.Errorf("query chat messages: %w", err)
	}
	defer rows.Close()
	items := make([]domainchat.Message, 0, limit+1)
	for rows.Next() {
		message, scanErr := scanMessage(rows)
		if scanErr != nil {
			return domainchat.MessagePage{}, scanErr
		}
		items = append(items, message)
	}
	if err := rows.Err(); err != nil {
		return domainchat.MessagePage{}, fmt.Errorf("iterate chat messages: %w", err)
	}
	page := domainchat.MessagePage{Messages: reverseMessages(items)}
	if len(items) > limit {
		page.Messages = reverseMessages(items[:limit])
		page.NextCursor = fmt.Sprintf("%d", items[limit-1].Sequence)
	}
	return page, nil
}

func (repository *Repository) CreateMessage(
	ctx context.Context,
	userID string,
	input domainchat.SendMessage,
) (domainchat.Message, []string, bool, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainchat.Message{}, nil, false, fmt.Errorf("begin message: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`, userID+":"+input.ClientID); err != nil {
		return domainchat.Message{}, nil, false, fmt.Errorf("lock message idempotency key: %w", err)
	}
	if existing, found, err := findMessageByClientID(ctx, tx, userID, input.ClientID); err != nil {
		return domainchat.Message{}, nil, false, err
	} else if found {
		if existing.ConversationID != input.ConversationID {
			return domainchat.Message{}, nil, false, domainchat.ErrInvalidMessage
		}
		recipients, err := conversationRecipients(ctx, tx, userID, input.ConversationID)
		return existing, recipients, false, err
	}
	if _, err := conversationRecipients(ctx, tx, userID, input.ConversationID); err != nil {
		return domainchat.Message{}, nil, false, err
	}
	var sequence int64
	if err := tx.QueryRow(ctx, `
		UPDATE conversations
		SET last_sequence = last_sequence + 1, updated_at = now()
		WHERE id = $1::uuid
		RETURNING last_sequence`, input.ConversationID).Scan(&sequence); err != nil {
		return domainchat.Message{}, nil, false, mapChatError(err)
	}
	var message domainchat.Message
	err = tx.QueryRow(ctx, `
		INSERT INTO chat_messages (conversation_id, sender_uid, client_id, sequence, content)
		VALUES ($1::uuid, $2, $3::uuid, $4, $5)
		RETURNING id::text, client_id::text, conversation_id::text, sender_uid,
		          content, sequence, created_at`,
		input.ConversationID, userID, input.ClientID, sequence, input.Content,
	).Scan(
		&message.ID, &message.ClientID, &message.ConversationID, &message.SenderUID,
		&message.Content, &message.Sequence, &message.CreatedAt,
	)
	if err != nil {
		return domainchat.Message{}, nil, false, fmt.Errorf("insert chat message: %w", err)
	}
	message.Status = domainchat.StatusSent
	recipients, err := conversationRecipients(ctx, tx, userID, input.ConversationID)
	if err != nil {
		return domainchat.Message{}, nil, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domainchat.Message{}, nil, false, fmt.Errorf("commit chat message: %w", err)
	}
	return message, recipients, true, nil
}

func findMessageByClientID(
	ctx context.Context,
	query interface {
		QueryRow(context.Context, string, ...any) pgx.Row
	},
	userID, clientID string,
) (domainchat.Message, bool, error) {
	message, err := scanMessage(query.QueryRow(ctx, `SELECT `+messageColumns+`
		FROM chat_messages m WHERE m.sender_uid = $1 AND m.client_id = $2::uuid`, userID, clientID))
	if errors.Is(err, pgx.ErrNoRows) {
		return domainchat.Message{}, false, nil
	}
	if err != nil {
		return domainchat.Message{}, false, err
	}
	return message, true, nil
}

func scanMessage(row rowScanner) (domainchat.Message, error) {
	var message domainchat.Message
	if err := row.Scan(
		&message.ID, &message.ClientID, &message.ConversationID, &message.SenderUID,
		&message.Content, &message.Sequence, &message.CreatedAt, &message.Status,
	); err != nil {
		return domainchat.Message{}, err
	}
	return message, nil
}

func reverseMessages(values []domainchat.Message) []domainchat.Message {
	result := make([]domainchat.Message, len(values))
	for index := range values {
		result[len(values)-1-index] = values[index]
	}
	return result
}
