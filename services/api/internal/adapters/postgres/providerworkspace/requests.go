package providerworkspace

import (
	"context"
	"fmt"

	"github.com/vendlydigital/help/services/api/internal/domain/providers"
)

func (repository *Repository) ListRecentRequests(
	ctx context.Context,
	uid string,
	limit int,
) ([]providers.ServiceRequest, error) {
	rows, err := repository.pool.Query(ctx, `
		SELECT request.id::text, request.service_id, service.title,
		       customer.display_name, request.status, request.note,
		       request.quoted_price_cents, request.formatted_address,
		       request.scheduled_for, request.created_at
		FROM service_requests request
		JOIN providers provider ON provider.id = request.provider_id
		JOIN services service ON service.id = request.service_id
		JOIN user_profiles customer ON customer.firebase_uid = request.customer_uid
		WHERE provider.owner_uid = $1
		ORDER BY request.updated_at DESC, request.id DESC
		LIMIT $2`, uid, limit)
	if err != nil {
		return nil, fmt.Errorf("query provider requests: %w", err)
	}
	defer rows.Close()

	requests := make([]providers.ServiceRequest, 0, limit)
	for rows.Next() {
		var request providers.ServiceRequest
		if err := rows.Scan(
			&request.ID, &request.ServiceID, &request.ServiceTitle, &request.CustomerName,
			&request.Status, &request.Note, &request.QuotedPriceCents, &request.Address,
			&request.ScheduledFor, &request.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan provider request: %w", err)
		}
		requests = append(requests, request)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate provider requests: %w", err)
	}
	return requests, nil
}
