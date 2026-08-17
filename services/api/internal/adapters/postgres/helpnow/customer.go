package helpnow

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

func (repository *Repository) Create(ctx context.Context, uid string, input domainhelp.CreateInput, now time.Time) (domainhelp.Request, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainhelp.Request{}, fmt.Errorf("begin help now request: %w", err)
	}
	defer tx.Rollback(ctx)
	existing, err := scanRequest(tx.QueryRow(ctx, requestSelect+`
		WHERE request.customer_uid=$1 AND request.client_request_id=$2::uuid`, uid, input.ClientID))
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
	var hasActive bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(
		SELECT 1 FROM help_now_requests urgent
		LEFT JOIN service_requests service_request ON service_request.id=urgent.service_request_id
		WHERE urgent.customer_uid=$1 AND (urgent.status='searching' OR
			(urgent.status='assigned' AND service_request.status IN ('accepted','in_progress')))
	)`, uid).Scan(&hasActive); err != nil {
		return domainhelp.Request{}, fmt.Errorf("check active help now request: %w", err)
	}
	if hasActive {
		return domainhelp.Request{}, domainhelp.ErrActiveRequest
	}
	var recentRequests int
	if err := tx.QueryRow(ctx, `SELECT count(*) FROM help_now_requests
		WHERE customer_uid=$1 AND created_at>=$2::timestamptz-interval '15 minutes'`, uid, now).Scan(&recentRequests); err != nil {
		return domainhelp.Request{}, fmt.Errorf("count recent help now requests: %w", err)
	}
	if recentRequests >= 3 {
		return domainhelp.Request{}, domainhelp.ErrRateLimited
	}
	var eligible bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(
		SELECT 1 FROM user_roles role JOIN categories category ON category.id=$2 AND category.active
		WHERE role.firebase_uid=$1 AND role.role='customer'
	)`, uid, input.CategoryID).Scan(&eligible); err != nil {
		return domainhelp.Request{}, fmt.Errorf("validate help now customer: %w", err)
	}
	if !eligible {
		return domainhelp.Request{}, domainhelp.ErrForbidden
	}
	var id string
	err = tx.QueryRow(ctx, `INSERT INTO help_now_requests(
		client_request_id,customer_uid,category_id,note,address_label,formatted_address,
		latitude,longitude,next_dispatch_at,search_expires_at
	) VALUES($1::uuid,$2,$3,$4,$5,$6,$7,$8,$9::timestamptz,$9::timestamptz+interval '3 minutes') RETURNING id::text`,
		input.ClientID, uid, input.CategoryID, input.Note, input.AddressLabel, input.Address,
		input.Latitude, input.Longitude, now).Scan(&id)
	if err != nil {
		var postgresError *pgconn.PgError
		if errors.As(err, &postgresError) && postgresError.Code == "23505" {
			return domainhelp.Request{}, domainhelp.ErrActiveRequest
		}
		return domainhelp.Request{}, fmt.Errorf("insert help now request: %w", err)
	}
	request, err := scanRequest(tx.QueryRow(ctx, requestSelect+` WHERE request.id=$1::uuid`, id))
	if err != nil {
		return domainhelp.Request{}, fmt.Errorf("load created help now request: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domainhelp.Request{}, fmt.Errorf("commit help now request: %w", err)
	}
	return request, nil
}

func (repository *Repository) GetActive(ctx context.Context, uid string) (*domainhelp.Request, error) {
	request, err := scanRequest(repository.pool.QueryRow(ctx, requestSelect+`
		LEFT JOIN service_requests service_request ON service_request.id=request.service_request_id
		WHERE request.customer_uid=$1 AND (
			request.status='searching' OR
			(request.status='assigned' AND service_request.status IN ('accepted','in_progress')) OR
			(request.status IN ('no_provider','cancelled') AND request.updated_at>now()-interval '5 minutes')
		) ORDER BY request.updated_at DESC LIMIT 1`, uid))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("load active help now request: %w", err)
	}
	return &request, nil
}

func (repository *Repository) Cancel(ctx context.Context, uid, requestID string) (domainhelp.Request, error) {
	command, err := repository.pool.Exec(ctx, `UPDATE help_now_requests SET status='cancelled',updated_at=now()
		WHERE id=$1::uuid AND customer_uid=$2 AND status='searching'`, requestID, uid)
	if err != nil {
		return domainhelp.Request{}, fmt.Errorf("cancel help now request: %w", err)
	}
	if command.RowsAffected() == 0 {
		return domainhelp.Request{}, domainhelp.ErrNotFound
	}
	return repository.requestByID(ctx, requestID)
}
