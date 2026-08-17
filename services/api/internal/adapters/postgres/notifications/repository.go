package notifications

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

func (repository *Repository) EnqueueDueReminders(ctx context.Context, now time.Time, limit int) (int, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin due service request reminders: %w", err)
	}
	defer tx.Rollback(ctx)
	rows, err := tx.Query(ctx, `
		WITH due_requests AS (
			SELECT request.id, request.service_id, request.customer_uid,
			       provider.owner_uid AS provider_uid, service.title, request.scheduled_for,
			       CASE WHEN request.scheduled_for <= $1::timestamptz + interval '1 hour' THEN '1h' ELSE '24h' END AS reminder_kind
			FROM service_requests request
			JOIN services service ON service.id = request.service_id
			JOIN providers provider ON provider.id = request.provider_id
			WHERE request.status = 'accepted'
			  AND request.scheduled_for > $1::timestamptz
			  AND request.scheduled_for <= $1::timestamptz + interval '24 hours'
			ORDER BY request.scheduled_for, request.id
			LIMIT $2
		), recipients AS (
			SELECT due.id AS request_id, due.service_id, due.title, due.scheduled_for,
			       due.reminder_kind, recipient.uid, recipient.audience
			FROM due_requests due
			CROSS JOIN LATERAL (VALUES
				(due.customer_uid, 'customer'), (due.provider_uid, 'provider')
			) recipient(uid, audience)
		), claimed AS (
			INSERT INTO service_request_reminder_dispatches(request_id, recipient_uid, reminder_kind)
			SELECT request_id, uid, reminder_kind FROM recipients
			ON CONFLICT DO NOTHING
			RETURNING request_id, recipient_uid, reminder_kind
		), created AS (
			INSERT INTO notifications(firebase_uid, title, body, kind, data)
			SELECT recipient.uid,
			       CASE recipient.reminder_kind WHEN '1h' THEN 'Seu atendimento começa em breve' ELSE 'Lembrete de atendimento' END,
			       CASE recipient.reminder_kind WHEN '1h' THEN recipient.title || ' começa em até 1 hora.' ELSE recipient.title || ' está agendado para as próximas 24 horas.' END,
			       'service_request_reminder',
			       jsonb_build_object('request_id', recipient.request_id::text, 'service_id', recipient.service_id, 'route', 'service_request', 'reminder_kind', recipient.reminder_kind, 'audience', recipient.audience)
			FROM recipients recipient
			JOIN claimed ON claimed.request_id=recipient.request_id
			 AND claimed.recipient_uid=recipient.uid AND claimed.reminder_kind=recipient.reminder_kind
			RETURNING id, firebase_uid, data
		)
		INSERT INTO notification_push_outbox(notification_id)
		SELECT id FROM created
		RETURNING notification_id`, now, limit)
	if err != nil {
		return 0, fmt.Errorf("enqueue due service request reminders: %w", err)
	}
	ids := make([]uuid.UUID, 0, limit*2)
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return 0, fmt.Errorf("scan due service request reminder: %w", err)
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return 0, fmt.Errorf("read due service request reminders: %w", err)
	}
	rows.Close()
	if len(ids) > 0 {
		if _, err := tx.Exec(ctx, `
		UPDATE service_request_reminder_dispatches dispatch SET notification_id=notification.id
		FROM notifications notification
		WHERE dispatch.notification_id IS NULL
		  AND notification.id=ANY($1)
		  AND dispatch.request_id=(notification.data->>'request_id')::uuid
		  AND dispatch.recipient_uid=notification.firebase_uid
		  AND dispatch.reminder_kind=notification.data->>'reminder_kind'
		  AND notification.kind='service_request_reminder'`, ids); err != nil {
			return 0, fmt.Errorf("link service request reminders: %w", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit service request reminders: %w", err)
	}
	return len(ids), nil
}

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (repository *Repository) CreateChatNotification(
	ctx context.Context,
	userID, conversationID string,
) error {
	_, err := repository.pool.Exec(ctx, `
		WITH notification AS (
			INSERT INTO notifications (firebase_uid, title, body, kind, data)
			VALUES ($1, 'Nova mensagem', 'Você recebeu uma nova mensagem.', 'chat',
			        jsonb_build_object('conversation_id', $2::text, 'route', 'chat'))
			RETURNING id
		)
		INSERT INTO notification_push_outbox (notification_id)
		SELECT id FROM notification`, userID, conversationID)
	if err != nil {
		return fmt.Errorf("insert chat notification: %w", err)
	}
	return nil
}

func (repository *Repository) CreateConversationRequestNotification(
	ctx context.Context,
	userID, conversationID string,
) error {
	_, err := repository.pool.Exec(ctx, `
		WITH notification AS (
			INSERT INTO notifications (firebase_uid, title, body, kind, data)
			VALUES ($1, 'Nova solicitação de conversa',
			        'Uma pessoa quer iniciar uma conversa com você.', 'chat_request',
			        jsonb_build_object('conversation_id', $2::text, 'route', 'chat'))
			RETURNING id
		)
		INSERT INTO notification_push_outbox (notification_id)
		SELECT id FROM notification`, userID, conversationID)
	if err != nil {
		return fmt.Errorf("insert conversation request notification: %w", err)
	}
	return nil
}
