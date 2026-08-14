package notifications

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (repository *Repository) CreateChatNotification(
	ctx context.Context,
	userID, conversationID string,
) error {
	_, err := repository.pool.Exec(ctx, `
		INSERT INTO notifications (firebase_uid, title, body, kind, data)
		VALUES ($1, 'Nova mensagem', 'Você recebeu uma nova mensagem.', 'chat',
		        jsonb_build_object('conversation_id', $2::text))`, userID, conversationID)
	if err != nil {
		return fmt.Errorf("insert chat notification: %w", err)
	}
	return nil
}
