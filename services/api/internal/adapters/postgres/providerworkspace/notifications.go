package providerworkspace

import (
	"context"
	"fmt"

	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

func (repository *Repository) ListNotifications(
	ctx context.Context,
	uid string,
	limit int,
) ([]providers.WorkspaceNotification, error) {
	rows, err := repository.pool.Query(ctx, `
		SELECT id::text, title, body, kind, data, read_at IS NOT NULL, created_at
		FROM notifications
		WHERE firebase_uid = $1
		ORDER BY created_at DESC
		LIMIT $2`, uid, limit)
	if err != nil {
		return nil, fmt.Errorf("query provider notifications: %w", err)
	}
	defer rows.Close()

	notifications := make([]providers.WorkspaceNotification, 0, limit)
	for rows.Next() {
		var notification providers.WorkspaceNotification
		if err := rows.Scan(
			&notification.ID, &notification.Title, &notification.Body,
			&notification.Kind, &notification.Data,
			&notification.Read, &notification.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan provider notification: %w", err)
		}
		notifications = append(notifications, notification)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate provider notifications: %w", err)
	}
	return notifications, nil
}
