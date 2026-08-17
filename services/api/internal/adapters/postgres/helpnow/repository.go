package helpnow

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

const requestSelect = `
	SELECT request.id::text, request.client_request_id::text, request.customer_uid,
	       customer.display_name, request.category_id, category.name, request.note,
	       request.address_label, request.formatted_address, request.latitude,
	       request.longitude, request.status, request.search_wave,
	       COALESCE(request.assigned_provider_id, ''), COALESCE(provider.name, ''),
	       COALESCE(request.service_request_id::text, ''), request.created_at,
	       request.updated_at, request.search_expires_at
	FROM help_now_requests request
	JOIN user_profiles customer ON customer.firebase_uid=request.customer_uid
	JOIN categories category ON category.id=request.category_id
	LEFT JOIN providers provider ON provider.id=request.assigned_provider_id
`

type rowScanner interface{ Scan(...any) error }

func scanRequest(row rowScanner) (domainhelp.Request, error) {
	var request domainhelp.Request
	err := row.Scan(&request.ID, &request.ClientID, &request.CustomerID, &request.CustomerName,
		&request.CategoryID, &request.CategoryName, &request.Note, &request.AddressLabel,
		&request.Address, &request.Latitude, &request.Longitude, &request.Status,
		&request.Wave, &request.AssignedProviderID, &request.AssignedProviderName,
		&request.ServiceRequestID, &request.CreatedAt, &request.UpdatedAt, &request.SearchExpiresAt)
	return request, err
}

func (repository *Repository) requestByID(ctx context.Context, id string) (domainhelp.Request, error) {
	request, err := scanRequest(repository.pool.QueryRow(ctx, requestSelect+` WHERE request.id=$1::uuid`, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return domainhelp.Request{}, domainhelp.ErrNotFound
	}
	if err != nil {
		return domainhelp.Request{}, fmt.Errorf("load help now request: %w", err)
	}
	return request, nil
}
