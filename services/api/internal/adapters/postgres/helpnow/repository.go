package helpnow

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Masterminds/squirrel"
	"github.com/vendlydigital/help/services/api/internal/database"
	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

type Repository struct{ pool *pgxpool.Pool }

func NewRepository(pool *pgxpool.Pool) *Repository { return &Repository{pool: pool} }

func requestQuery() squirrel.SelectBuilder {
	return database.Query.Select(
		"request.id::text", "request.client_request_id::text", "request.customer_uid",
		"customer.display_name", "COALESCE(request.category_id, '')", "COALESCE(category.name, 'Ajuda geral')",
		"request.note", "request.address_label", "request.formatted_address", "request.latitude",
		"request.longitude", "request.status", "request.search_wave",
		"COALESCE(request.assigned_provider_id, '')", "COALESCE(provider.name, '')",
		"COALESCE(request.service_request_id::text, '')", "request.created_at",
		"request.updated_at", "request.search_expires_at",
	).From("help_now_requests request").
		Join("user_profiles customer ON customer.firebase_uid=request.customer_uid").
		LeftJoin("categories category ON category.id=request.category_id").
		LeftJoin("providers provider ON provider.id=request.assigned_provider_id")
}

type rowScanner interface{ Scan(...any) error }
type queryRower interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}

func scanRequest(row rowScanner) (domainhelp.Request, error) {
	var request domainhelp.Request
	err := row.Scan(&request.ID, &request.ClientID, &request.CustomerID, &request.CustomerName,
		&request.CategoryID, &request.CategoryName, &request.Note, &request.AddressLabel,
		&request.Address, &request.Latitude, &request.Longitude, &request.Status,
		&request.Wave, &request.AssignedProviderID, &request.AssignedProviderName,
		&request.ServiceRequestID, &request.CreatedAt, &request.UpdatedAt, &request.SearchExpiresAt)
	return request, err
}

func queryRequest(ctx context.Context, queryer queryRower, id string) (domainhelp.Request, error) {
	query, args, err := requestQuery().Where("request.id = ?::uuid", id).ToSql()
	if err != nil {
		return domainhelp.Request{}, fmt.Errorf("build help now request query: %w", err)
	}
	return scanRequest(queryer.QueryRow(ctx, query, args...))
}

func (repository *Repository) requestByID(ctx context.Context, id string) (domainhelp.Request, error) {
	request, err := queryRequest(ctx, repository.pool, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainhelp.Request{}, domainhelp.ErrNotFound
	}
	if err != nil {
		return domainhelp.Request{}, fmt.Errorf("load help now request: %w", err)
	}
	return request, nil
}
