package providerworkspace

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/vendlydigital/help/services/api/internal/domain/catalog"
	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func (repository *Repository) GetOverview(
	ctx context.Context,
	uid string,
) (providers.WorkspaceOverview, error) {
	var overview providers.WorkspaceOverview
	err := repository.pool.QueryRow(ctx, `
		SELECT provider.id, profile.display_name, provider.onboarding_status,
		       provider.active, provider.accepting_requests,
		       COALESCE(address.formatted_address, ''), address.latitude, address.longitude,
		       (SELECT count(*) FROM notifications n WHERE n.firebase_uid = $1 AND n.read_at IS NULL),
		       (SELECT count(*)
		          FROM conversation_members member
		          JOIN chat_messages message ON message.conversation_id = member.conversation_id
		         WHERE member.firebase_uid = $1
		           AND message.sender_uid <> $1
		           AND message.sequence > member.last_read_sequence),
		       (SELECT count(*) FROM service_requests request
		         WHERE request.provider_id = provider.id AND request.status = 'pending')
		FROM user_profiles profile
		JOIN providers provider ON provider.owner_uid = profile.firebase_uid
		LEFT JOIN LATERAL (
			SELECT formatted_address, latitude, longitude
			FROM user_addresses
			WHERE firebase_uid = profile.firebase_uid AND is_default AND active
			LIMIT 1
		) address ON true
		WHERE profile.firebase_uid = $1`, uid).Scan(
		&overview.ProviderID, &overview.DisplayName, &overview.Status,
		&overview.Active, &overview.AcceptingRequests,
		&overview.Location.Address, &overview.Location.Latitude, &overview.Location.Longitude,
		&overview.UnreadNotifications, &overview.UnreadMessages, &overview.PendingRequests,
	)
	if err == pgx.ErrNoRows {
		return providers.WorkspaceOverview{}, providers.ErrWorkspaceNotFound
	}
	if err != nil {
		return providers.WorkspaceOverview{}, fmt.Errorf("query provider overview: %w", err)
	}
	return overview, nil
}

func (repository *Repository) ListServices(ctx context.Context, uid string) ([]catalog.Service, error) {
	rows, err := repository.pool.Query(ctx, `
		SELECT service.id, service.provider_id, COALESCE(service.category_id, ''),
		       service.title, service.description, service.rating::float8, service.reviews,
		       service.duration_minutes, service.price_cents, service.old_price_cents,
		       service.image_url, service.image_alignment, service.badge, service.active,
		       service.published_at, service.created_at, service.updated_at
		FROM services service
		JOIN providers provider ON provider.id = service.provider_id
		WHERE provider.owner_uid = $1 AND service.deleted_at IS NULL
		ORDER BY service.updated_at DESC, service.id`, uid)
	if err != nil {
		return nil, fmt.Errorf("query provider services: %w", err)
	}
	defer rows.Close()

	services := make([]catalog.Service, 0)
	for rows.Next() {
		service, scanErr := scanService(rows)
		if scanErr != nil {
			return nil, fmt.Errorf("scan provider service: %w", scanErr)
		}
		services = append(services, service)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate provider services: %w", err)
	}
	return services, nil
}

type rowScanner interface{ Scan(dest ...any) error }

func scanService(row rowScanner) (catalog.Service, error) {
	var service catalog.Service
	err := row.Scan(
		&service.ID, &service.ProviderID, &service.CategoryID,
		&service.Title, &service.Description, &service.Rating, &service.Reviews,
		&service.DurationMinutes, &service.PriceCents, &service.OldPriceCents,
		&service.ImageURL, &service.ImageAlignment, &service.Badge, &service.Active,
		&service.PublishedAt, &service.CreatedAt, &service.UpdatedAt,
	)
	return service, err
}
