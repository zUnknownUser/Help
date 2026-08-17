package home

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainhome "github.com/vendlydigital/help/services/api/internal/domain/home"
)

type ViewerRepository struct{ pool *pgxpool.Pool }

type notificationRow struct {
	ID        string            `json:"id"`
	Title     string            `json:"title"`
	Body      string            `json:"body"`
	Kind      string            `json:"kind"`
	Data      map[string]string `json:"data"`
	ReadAt    *time.Time        `json:"read_at"`
	CreatedAt time.Time         `json:"created_at"`
}

func NewViewerRepository(pool *pgxpool.Pool) *ViewerRepository {
	return &ViewerRepository{pool: pool}
}

func (repository *ViewerRepository) GetViewer(
	ctx context.Context,
	uid string,
) (domainhome.Viewer, error) {
	var viewer domainhome.Viewer
	var notificationsJSON []byte
	err := repository.pool.QueryRow(ctx, `
		SELECT
			COALESCE((SELECT formatted_address FROM user_addresses WHERE firebase_uid = $1 AND is_default AND active LIMIT 1), ''),
			COALESCE((SELECT label FROM user_addresses WHERE firebase_uid = $1 AND is_default AND active LIMIT 1), ''),
			(SELECT latitude FROM user_addresses WHERE firebase_uid = $1 AND is_default AND active LIMIT 1),
			(SELECT longitude FROM user_addresses WHERE firebase_uid = $1 AND is_default AND active LIMIT 1),
			(SELECT count(*) FROM notifications WHERE firebase_uid = $1 AND read_at IS NULL),
			COALESCE((
				SELECT jsonb_agg(jsonb_build_object(
					'id', n.id, 'title', n.title, 'body', n.body,
					'kind', n.kind, 'data', n.data,
					'read_at', n.read_at, 'created_at', n.created_at
				) ORDER BY n.created_at DESC)
				FROM (
					SELECT id, title, body, kind, data, read_at, created_at
					FROM notifications
					WHERE firebase_uid = $1
					ORDER BY created_at DESC
					LIMIT 20
				) n
			), '[]'::jsonb)`, uid).Scan(
		&viewer.Location.Address,
		&viewer.Location.AvailabilityLabel,
		&viewer.Location.Latitude,
		&viewer.Location.Longitude,
		&viewer.UnreadNotificationCount,
		&notificationsJSON,
	)
	if err != nil {
		return domainhome.Viewer{}, fmt.Errorf("query home viewer: %w", err)
	}
	var rows []notificationRow
	if err := json.Unmarshal(notificationsJSON, &rows); err != nil {
		return domainhome.Viewer{}, fmt.Errorf("decode home notifications: %w", err)
	}
	for _, row := range rows {
		viewer.Notifications = append(viewer.Notifications, domainhome.Notification{
			ID: row.ID, Title: row.Title, Body: row.Body,
			Kind: row.Kind, Data: row.Data,
			Read: row.ReadAt != nil, CreatedAt: row.CreatedAt.UTC().Format(time.RFC3339),
		})
	}
	return viewer, nil
}

func (repository *ViewerRepository) MarkRead(
	ctx context.Context,
	uid, notificationID string,
) error {
	query, args, buildErr := database.Query.Update("notifications").
		Set("read_at", database.Expr("COALESCE(read_at, now())")).
		Where("firebase_uid = ?", uid).Where("id = ?::uuid", notificationID).ToSql()
	if buildErr != nil {
		return fmt.Errorf("build mark notification read: %w", buildErr)
	}
	_, err := repository.pool.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("mark notification read: %w", err)
	}
	return nil
}

func (repository *ViewerRepository) MarkAllRead(ctx context.Context, uid string) (int, error) {
	query, args, err := database.Query.Update("notifications").Set("read_at", database.Expr("now()")).
		Where("firebase_uid = ?", uid).Where("read_at IS NULL").ToSql()
	if err != nil {
		return 0, fmt.Errorf("build mark all notifications read: %w", err)
	}
	result, err := repository.pool.Exec(ctx, query, args...)
	if err != nil {
		return 0, fmt.Errorf("mark all notifications read: %w", err)
	}
	return int(result.RowsAffected()), nil
}
