package notifications

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	sq "github.com/Masterminds/squirrel"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
	"github.com/vendlydigital/help/services/api/internal/database"
)

func (repository *Repository) Claim(ctx context.Context, limit int) ([]ports.PushDelivery, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin push outbox claim: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	candidateQuery, candidateArgs, err := database.Query.Select("outbox.notification_id::text").
		From("notification_push_outbox outbox").Where("outbox.delivered_at IS NULL").
		Where("outbox.available_at <= now()").
		Where("outbox.locked_at IS NULL OR outbox.locked_at < now() - interval '2 minutes'").
		OrderBy("outbox.available_at", "outbox.notification_id").Limit(uint64(limit)).
		Suffix("FOR UPDATE SKIP LOCKED").ToSql()
	if err != nil {
		return nil, fmt.Errorf("build push outbox candidates: %w", err)
	}
	candidateRows, err := tx.Query(ctx, candidateQuery, candidateArgs...)
	if err != nil {
		return nil, fmt.Errorf("query push outbox candidates: %w", err)
	}
	ids := make([]string, 0, limit)
	for candidateRows.Next() {
		var id string
		if err = candidateRows.Scan(&id); err != nil {
			candidateRows.Close()
			return nil, err
		}
		ids = append(ids, id)
	}
	candidateRows.Close()
	if len(ids) == 0 {
		_ = tx.Commit(ctx)
		return []ports.PushDelivery{}, nil
	}
	updateQuery, updateArgs, err := database.Query.Update("notification_push_outbox").
		Set("locked_at", database.Expr("now()")).Set("attempts", database.Expr("attempts + 1")).
		Where(sq.Eq{"notification_id": ids}).ToSql()
	if err != nil {
		return nil, fmt.Errorf("build push outbox claim: %w", err)
	}
	if _, err = tx.Exec(ctx, updateQuery, updateArgs...); err != nil {
		return nil, fmt.Errorf("claim push outbox: %w", err)
	}
	query, args, err := database.Query.Select(
		"outbox.notification_id::text", "notification.firebase_uid", "notification.title",
		"notification.body", "notification.kind", "notification.data", "outbox.attempts",
		`(SELECT count(*) FROM notifications unread
		 WHERE unread.firebase_uid=notification.firebase_uid AND unread.read_at IS NULL)`,
	).From("notification_push_outbox outbox").
		Join("notifications notification ON notification.id=outbox.notification_id").
		Where(sq.Eq{"outbox.notification_id": ids}).ToSql()
	if err != nil {
		return nil, fmt.Errorf("build claimed push query: %w", err)
	}
	rows, err := tx.Query(ctx, query, args...)
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
			&delivery.Message.Body, &kind, &raw, &delivery.Attempts, &delivery.Message.Badge); err != nil {
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
	if err = rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()
	if err = tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit push claim: %w", err)
	}
	return deliveries, nil
}

func (repository *Repository) MarkDelivered(ctx context.Context, notificationID string) error {
	query, args, buildErr := database.Query.Update("notification_push_outbox").
		Set("delivered_at", database.Expr("now()")).Set("locked_at", nil).Set("last_error", "").
		Where("notification_id = ?::uuid", notificationID).ToSql()
	if buildErr != nil {
		return fmt.Errorf("build push delivery update: %w", buildErr)
	}
	_, err := repository.pool.Exec(ctx, query, args...)
	return err
}

func (repository *Repository) Reschedule(ctx context.Context, notificationID string, availableAt time.Time, lastError string) error {
	if len(lastError) > 500 {
		lastError = lastError[:500]
	}
	query, args, buildErr := database.Query.Update("notification_push_outbox").
		Set("available_at", availableAt).Set("locked_at", nil).Set("last_error", lastError).
		Where("notification_id = ?::uuid", notificationID).ToSql()
	if buildErr != nil {
		return fmt.Errorf("build push retry update: %w", buildErr)
	}
	_, err := repository.pool.Exec(ctx, query, args...)
	return err
}
