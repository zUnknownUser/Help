package helpnow

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

func (repository *Repository) Create(ctx context.Context, uid string, input domainhelp.CreateInput, now time.Time) (domainhelp.Request, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainhelp.Request{}, fmt.Errorf("begin help now request: %w", err)
	}
	defer tx.Rollback(ctx)
	query, args, buildErr := requestQuery().Where("request.customer_uid = ?", uid).
		Where("request.client_request_id = ?::uuid", input.ClientID).ToSql()
	if buildErr != nil {
		return domainhelp.Request{}, fmt.Errorf("build existing help now query: %w", buildErr)
	}
	existing, err := scanRequest(tx.QueryRow(ctx, query, args...))
	if err == nil {
		if existing.CategoryID != input.CategoryID || existing.Note != input.Note ||
			existing.Latitude != input.Latitude || existing.Longitude != input.Longitude {
			return domainhelp.Request{}, domainhelp.ErrIdempotency
		}
		return existing, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return domainhelp.Request{}, fmt.Errorf("find help now request: %w", err)
	}
	activeSubquery := database.Query.Select("1").From("help_now_requests urgent").
		LeftJoin("service_requests service_request ON service_request.id=urgent.service_request_id").
		Where("urgent.customer_uid = ?", uid).
		Where("urgent.status='searching' OR (urgent.status='assigned' AND service_request.status IN ('accepted','in_progress'))")
	query, args, buildErr = database.Query.Select().Column(database.Expr("EXISTS (?)", activeSubquery)).ToSql()
	if buildErr != nil {
		return domainhelp.Request{}, fmt.Errorf("build active help now check: %w", buildErr)
	}
	var hasActive bool
	if err := tx.QueryRow(ctx, query, args...).Scan(&hasActive); err != nil {
		return domainhelp.Request{}, fmt.Errorf("check active help now request: %w", err)
	}
	if hasActive {
		return domainhelp.Request{}, domainhelp.ErrActiveRequest
	}
	query, args, buildErr = database.Query.Select("count(*)").From("help_now_requests").
		Where("customer_uid = ?", uid).Where("created_at >= ?", now.Add(-15*time.Minute)).ToSql()
	if buildErr != nil {
		return domainhelp.Request{}, fmt.Errorf("build recent help now query: %w", buildErr)
	}
	var recentRequests int
	if err := tx.QueryRow(ctx, query, args...).Scan(&recentRequests); err != nil {
		return domainhelp.Request{}, fmt.Errorf("count recent help now requests: %w", err)
	}
	if recentRequests >= 3 {
		return domainhelp.Request{}, domainhelp.ErrRateLimited
	}
	eligibility := database.Query.Select("1").From("user_roles role").
		Where("role.firebase_uid = ?", uid).Where("role.role = 'customer'")
	if input.CategoryID != "" {
		eligibility = eligibility.Join("categories category ON category.id = ? AND category.active", input.CategoryID)
	}
	query, args, buildErr = database.Query.Select().Column(database.Expr("EXISTS (?)", eligibility)).ToSql()
	if buildErr != nil {
		return domainhelp.Request{}, fmt.Errorf("build help now eligibility: %w", buildErr)
	}
	var eligible bool
	if err := tx.QueryRow(ctx, query, args...).Scan(&eligible); err != nil {
		return domainhelp.Request{}, fmt.Errorf("validate help now customer: %w", err)
	}
	if !eligible {
		return domainhelp.Request{}, domainhelp.ErrForbidden
	}
	categoryID := any(nil)
	if input.CategoryID != "" {
		categoryID = input.CategoryID
	}
	query, args, buildErr = database.Query.Insert("help_now_requests").Columns(
		"client_request_id", "customer_uid", "category_id", "note", "address_label", "formatted_address",
		"latitude", "longitude", "next_dispatch_at", "search_expires_at",
	).Values(input.ClientID, uid, categoryID, input.Note, input.AddressLabel, input.Address,
		input.Latitude, input.Longitude, now, now.Add(3*time.Minute)).Suffix("RETURNING id::text").ToSql()
	if buildErr != nil {
		return domainhelp.Request{}, fmt.Errorf("build help now insert: %w", buildErr)
	}
	var id string
	err = tx.QueryRow(ctx, query, args...).Scan(&id)
	if err != nil {
		var postgresError *pgconn.PgError
		if errors.As(err, &postgresError) && postgresError.Code == "23505" {
			return domainhelp.Request{}, domainhelp.ErrActiveRequest
		}
		return domainhelp.Request{}, fmt.Errorf("insert help now request: %w", err)
	}
	query, args, buildErr = requestQuery().Where("request.id = ?::uuid", id).ToSql()
	if buildErr != nil {
		return domainhelp.Request{}, fmt.Errorf("build created help now query: %w", buildErr)
	}
	request, err := scanRequest(tx.QueryRow(ctx, query, args...))
	if err != nil {
		return domainhelp.Request{}, fmt.Errorf("load created help now request: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domainhelp.Request{}, fmt.Errorf("commit help now request: %w", err)
	}
	return request, nil
}

func (repository *Repository) GetActive(ctx context.Context, uid string) (*domainhelp.Request, error) {
	query, args, buildErr := requestQuery().LeftJoin("service_requests service_request ON service_request.id=request.service_request_id").
		Where("request.customer_uid = ?", uid).Where(`
			request.status='searching' OR
			(request.status='assigned' AND service_request.status IN ('accepted','in_progress')) OR
			(request.status IN ('no_provider','cancelled') AND request.updated_at>now()-interval '5 minutes')
		`).OrderBy("request.updated_at DESC").Limit(1).ToSql()
	if buildErr != nil {
		return nil, fmt.Errorf("build active help now query: %w", buildErr)
	}
	request, err := scanRequest(repository.pool.QueryRow(ctx, query, args...))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("load active help now request: %w", err)
	}
	return &request, nil
}

func (repository *Repository) Cancel(ctx context.Context, uid, requestID string) (domainhelp.Request, error) {
	query, args, buildErr := database.Query.Update("help_now_requests").Set("status", "cancelled").
		Set("updated_at", database.Expr("now()")).Where("id = ?::uuid", requestID).
		Where("customer_uid = ?", uid).Where("status = 'searching'").ToSql()
	if buildErr != nil {
		return domainhelp.Request{}, fmt.Errorf("build help now cancellation: %w", buildErr)
	}
	command, err := repository.pool.Exec(ctx, query, args...)
	if err != nil {
		return domainhelp.Request{}, fmt.Errorf("cancel help now request: %w", err)
	}
	if command.RowsAffected() == 0 {
		return domainhelp.Request{}, domainhelp.ErrNotFound
	}
	return repository.requestByID(ctx, requestID)
}
