package notifications

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

func (repository *Repository) Claim(ctx context.Context, limit int) ([]ports.PushDelivery, error) {
	rows, err := repository.pool.Query(ctx, `
		WITH candidates AS (
			SELECT outbox.notification_id
			FROM notification_push_outbox outbox
			WHERE outbox.delivered_at IS NULL AND outbox.available_at <= now()
			  AND (outbox.locked_at IS NULL OR outbox.locked_at < now() - interval '2 minutes')
			ORDER BY outbox.available_at, outbox.notification_id
			FOR UPDATE SKIP LOCKED LIMIT $1
		), claimed AS (
			UPDATE notification_push_outbox outbox
			SET locked_at = now(), attempts = attempts + 1
			FROM candidates WHERE outbox.notification_id = candidates.notification_id
			RETURNING outbox.notification_id, outbox.attempts
		)
		SELECT claimed.notification_id::text, notification.firebase_uid,
		       notification.title, notification.body, notification.kind,
		       notification.data, claimed.attempts
		FROM claimed JOIN notifications notification ON notification.id = claimed.notification_id`, limit)
	if err != nil {
		return nil, fmt.Errorf("claim push outbox: %w", err)
	}
	defer rows.Close()
	deliveries := make([]ports.PushDelivery, 0, limit)
	for rows.Next() {
		var delivery ports.PushDelivery
		var kind string
		var raw []byte
		if err := rows.Scan(&delivery.NotificationID, &delivery.UserID, &delivery.Message.Title,
			&delivery.Message.Body, &kind, &raw, &delivery.Attempts); err != nil {
			return nil, fmt.Errorf("scan push outbox: %w", err)
		}
		var values map[string]any
		if err := json.Unmarshal(raw, &values); err != nil {
			return nil, fmt.Errorf("decode push data: %w", err)
		}
		delivery.Message.Data = make(map[string]string, len(values)+1)
		delivery.Message.Data["type"] = kind
		for key, value := range values {
			if text, ok := value.(string); ok {
				delivery.Message.Data[key] = text
			}
		}
		deliveries = append(deliveries, delivery)
	}
	return deliveries, rows.Err()
}

func (repository *Repository) MarkDelivered(ctx context.Context, notificationID string) error {
	_, err := repository.pool.Exec(ctx, `UPDATE notification_push_outbox
		SET delivered_at = now(), locked_at = NULL, last_error = ''
		WHERE notification_id = $1::uuid`, notificationID)
	return err
}

func (repository *Repository) Reschedule(ctx context.Context, notificationID string, availableAt time.Time, lastError string) error {
	if len(lastError) > 500 {
		lastError = lastError[:500]
	}
	_, err := repository.pool.Exec(ctx, `UPDATE notification_push_outbox
		SET available_at = $2, locked_at = NULL, last_error = $3
		WHERE notification_id = $1::uuid`, notificationID, availableAt, lastError)
	return err
}
