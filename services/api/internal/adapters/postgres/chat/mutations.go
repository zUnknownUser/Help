package chat

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	domainchat "github.com/vendlydigital/help/services/api/internal/domain/chat"
)

func (repository *Repository) EditMessage(
	ctx context.Context,
	userID string,
	mutation domainchat.MessageMutation,
) (domainchat.Message, []string, bool, error) {
	return repository.mutateMessage(ctx, userID, mutation, false)
}

func (repository *Repository) DeleteMessage(
	ctx context.Context,
	userID string,
	mutation domainchat.MessageMutation,
) (domainchat.Message, []string, bool, error) {
	return repository.mutateMessage(ctx, userID, mutation, true)
}

func (repository *Repository) mutateMessage(
	ctx context.Context,
	userID string,
	mutation domainchat.MessageMutation,
	deleting bool,
) (domainchat.Message, []string, bool, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainchat.Message{}, nil, false, fmt.Errorf("begin message mutation: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx,
		`SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`,
		userID+":"+mutation.OperationID,
	); err != nil {
		return domainchat.Message{}, nil, false, fmt.Errorf("lock message mutation: %w", err)
	}

	existingID, err := mutationMessageID(ctx, tx, userID, mutation.OperationID)
	if err != nil {
		return domainchat.Message{}, nil, false, err
	}
	if existingID != "" {
		message, err := findMessageByID(ctx, tx, existingID)
		if err != nil {
			return domainchat.Message{}, nil, false, err
		}
		recipients, err := conversationRecipients(ctx, tx, userID, message.ConversationID)
		return message, recipients, false, err
	}

	query := `UPDATE chat_messages
		SET content = $3, edited_at = now(), version = version + 1
		WHERE id = $1::uuid AND sender_uid = $2 AND deleted_at IS NULL AND kind = 'text'`
	kind := "edit"
	if deleting {
		query = `UPDATE chat_messages
			SET content = '', deleted_at = now(), version = version + 1
			WHERE id = $1::uuid AND sender_uid = $2 AND deleted_at IS NULL`
		kind = "delete"
	}
	arguments := []any{mutation.MessageID, userID, mutation.Content}
	if deleting {
		arguments = arguments[:2]
	}
	command, err := tx.Exec(ctx, query, arguments...)
	if err != nil {
		return domainchat.Message{}, nil, false, fmt.Errorf("update chat message: %w", err)
	}
	if command.RowsAffected() == 0 {
		return domainchat.Message{}, nil, false, mutationAccessError(ctx, tx, userID, mutation.MessageID)
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO chat_message_mutations (operation_id, message_id, actor_uid, kind)
		VALUES ($1::uuid, $2::uuid, $3, $4)`,
		mutation.OperationID, mutation.MessageID, userID, kind,
	); err != nil {
		return domainchat.Message{}, nil, false, fmt.Errorf("record message mutation: %w", err)
	}
	message, err := findMessageByID(ctx, tx, mutation.MessageID)
	if err != nil {
		return domainchat.Message{}, nil, false, err
	}
	recipients, err := conversationRecipients(ctx, tx, userID, message.ConversationID)
	if err != nil {
		return domainchat.Message{}, nil, false, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domainchat.Message{}, nil, false, fmt.Errorf("commit message mutation: %w", err)
	}
	return message, recipients, true, nil
}

func mutationMessageID(
	ctx context.Context,
	query interface {
		QueryRow(context.Context, string, ...any) pgx.Row
	},
	userID, operationID string,
) (string, error) {
	var messageID string
	err := query.QueryRow(ctx, `SELECT message_id::text
		FROM chat_message_mutations
		WHERE operation_id = $1::uuid AND actor_uid = $2`, operationID, userID).Scan(&messageID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("find message mutation: %w", err)
	}
	return messageID, nil
}

func findMessageByID(
	ctx context.Context,
	query interface {
		QueryRow(context.Context, string, ...any) pgx.Row
	},
	messageID string,
) (domainchat.Message, error) {
	message, err := scanMessage(query.QueryRow(ctx, `SELECT `+messageColumns+`
		FROM chat_messages m WHERE m.id = $1::uuid`, messageID))
	if errors.Is(err, pgx.ErrNoRows) {
		return domainchat.Message{}, domainchat.ErrMessageNotFound
	}
	return message, err
}

func mutationAccessError(
	ctx context.Context,
	query interface {
		QueryRow(context.Context, string, ...any) pgx.Row
	},
	userID, messageID string,
) error {
	var senderID string
	err := query.QueryRow(ctx,
		`SELECT sender_uid FROM chat_messages WHERE id = $1::uuid`, messageID,
	).Scan(&senderID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainchat.ErrMessageNotFound
	}
	if err != nil {
		return fmt.Errorf("check message mutation access: %w", err)
	}
	if senderID != userID {
		return domainchat.ErrForbidden
	}
	return domainchat.ErrInvalidMessage
}
