package servicerequests

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

func (repository *Repository) List(
	ctx context.Context,
	uid string,
	role domainrequests.ViewerRole,
	cursor *domainrequests.Cursor,
	limit int,
) ([]domainrequests.Request, error) {
	ownerColumn := "request.customer_uid"
	if role == domainrequests.ViewerProvider {
		ownerColumn = "provider.owner_uid"
	}
	query := requestSelect + `
		WHERE ` + ownerColumn + ` = $1
		  AND ($2::timestamptz IS NULL OR (request.updated_at, request.id) < ($2, $3::uuid))
		ORDER BY request.updated_at DESC, request.id DESC
		LIMIT $4`
	var cursorTime *time.Time
	var cursorID *string
	if cursor != nil {
		cursorTime, cursorID = &cursor.UpdatedAt, &cursor.ID
	}
	rows, err := repository.pool.Query(ctx, query, uid, cursorTime, cursorID, limit)
	if err != nil {
		return nil, fmt.Errorf("list service requests: %w", err)
	}
	defer rows.Close()
	items := make([]domainrequests.Request, 0, limit)
	for rows.Next() {
		request, scanErr := repository.scanRequest(rows)
		if scanErr != nil {
			return nil, fmt.Errorf("scan service request: %w", scanErr)
		}
		request.ViewerRole = role
		items = append(items, request)
	}
	return items, rows.Err()
}

func (repository *Repository) Agenda(ctx context.Context, uid string, from, to time.Time, limit int) ([]domainrequests.Request, error) {
	rows, err := repository.pool.Query(ctx, requestSelect+`
		WHERE provider.owner_uid=$1 AND request.scheduled_for >= $2 AND request.scheduled_for < $3
		  AND request.status IN ('pending','accepted','in_progress','completed','no_show')
		ORDER BY request.scheduled_for,request.id
		LIMIT $4`, uid, from, to, limit)
	if err != nil {
		return nil, fmt.Errorf("list provider agenda: %w", err)
	}
	defer rows.Close()
	items := make([]domainrequests.Request, 0, limit)
	for rows.Next() {
		request, err := repository.scanRequest(rows)
		if err != nil {
			return nil, fmt.Errorf("scan provider agenda: %w", err)
		}
		request.ViewerRole = domainrequests.ViewerProvider
		items = append(items, request)
	}
	return items, rows.Err()
}

func (repository *Repository) Get(ctx context.Context, uid, requestID string) (domainrequests.Request, error) {
	request, err := repository.scanRequest(repository.pool.QueryRow(ctx, requestSelect+`
		WHERE request.id = $1::uuid
		  AND (request.customer_uid = $2 OR provider.owner_uid = $2)`, requestID, uid))
	if errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, domainrequests.ErrNotFound
	}
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("get service request: %w", err)
	}
	request.ViewerRole = viewerRole(request, uid)
	return request, nil
}

func (repository *Repository) Transition(
	ctx context.Context,
	uid, requestID string,
	transition domainrequests.Transition,
) (domainrequests.Request, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("begin service request transition: %w", err)
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`, uid+":"+transition.ClientID); err != nil {
		return domainrequests.Request{}, fmt.Errorf("lock service request command: %w", err)
	}
	var previousRequestID, previousTarget, previousReason string
	err = tx.QueryRow(ctx, `SELECT request_id::text, target_status, reason
		FROM service_request_commands WHERE actor_uid = $1 AND client_command_id = $2::uuid`,
		uid, transition.ClientID).Scan(&previousRequestID, &previousTarget, &previousReason)
	if err == nil {
		if previousRequestID != requestID || previousTarget != string(transition.Target) || previousReason != transition.Reason {
			return domainrequests.Request{}, domainrequests.ErrIdempotencyConflict
		}
		request, loadErr := repository.scanRequest(tx.QueryRow(ctx, requestSelect+`
			WHERE request.id = $1::uuid AND (request.customer_uid = $2 OR provider.owner_uid = $2)`, requestID, uid))
		if loadErr != nil {
			return domainrequests.Request{}, loadErr
		}
		request.ViewerRole = viewerRole(request, uid)
		return request, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, fmt.Errorf("find service request command: %w", err)
	}
	request, err := repository.scanRequest(tx.QueryRow(ctx, requestSelect+`
		WHERE request.id = $1::uuid FOR UPDATE OF request`, requestID))
	if errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, domainrequests.ErrNotFound
	}
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("lock service request: %w", err)
	}
	role := viewerRole(request, uid)
	if role == "" {
		return domainrequests.Request{}, domainrequests.ErrForbidden
	}
	if request.Version != transition.ExpectedVersion {
		return domainrequests.Request{}, domainrequests.ErrVersionConflict
	}
	if !domainrequests.CanTransition(request.Status, transition.Target, role) {
		return domainrequests.Request{}, domainrequests.ErrInvalidTransition
	}
	if transition.Target == domainrequests.StatusNoShow && time.Now().Before(request.ScheduledFor) {
		return domainrequests.Request{}, domainrequests.ErrInvalidTransition
	}
	if _, err = tx.Exec(ctx, `UPDATE service_requests SET
		status = $2, status_reason = $3, status_changed_at = now(), updated_at = now(), version = version + 1
		WHERE id = $1::uuid`, requestID, transition.Target, transition.Reason); err != nil {
		return domainrequests.Request{}, fmt.Errorf("update service request status: %w", err)
	}
	if _, err = tx.Exec(ctx, `INSERT INTO service_request_commands (
		actor_uid, client_command_id, request_id, target_status, reason, resulting_version
	) VALUES ($1, $2::uuid, $3::uuid, $4, $5, $6)`, uid, transition.ClientID, requestID, transition.Target, transition.Reason, request.Version+1); err != nil {
		return domainrequests.Request{}, fmt.Errorf("insert service request command: %w", err)
	}
	recipient := request.CustomerUID
	if role == domainrequests.ViewerCustomer {
		recipient = request.ProviderUID
	}
	title, body := transitionNotification(transition.Target, request.ServiceTitle)
	if _, err = tx.Exec(ctx, `WITH notification AS (
		INSERT INTO notifications (firebase_uid, title, body, kind, data)
		VALUES ($1, $2, $3, 'service_request', jsonb_build_object(
			'request_id', $4::text, 'service_id', $5::text, 'status', $6::text, 'route', 'service_request'
		)) RETURNING id
	) INSERT INTO notification_push_outbox (notification_id) SELECT id FROM notification`,
		recipient, title, body, requestID, request.ServiceID, transition.Target); err != nil {
		return domainrequests.Request{}, fmt.Errorf("enqueue service request notification: %w", err)
	}
	updated, err := repository.scanRequest(tx.QueryRow(ctx, requestSelect+` WHERE request.id = $1::uuid`, requestID))
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("load transitioned service request: %w", err)
	}
	updated.ViewerRole = role
	if err := tx.Commit(ctx); err != nil {
		return domainrequests.Request{}, fmt.Errorf("commit service request transition: %w", err)
	}
	return updated, nil
}

func viewerRole(request domainrequests.Request, uid string) domainrequests.ViewerRole {
	if request.CustomerUID == uid {
		return domainrequests.ViewerCustomer
	}
	if request.ProviderUID == uid {
		return domainrequests.ViewerProvider
	}
	return ""
}

func transitionNotification(status domainrequests.Status, serviceTitle string) (string, string) {
	switch status {
	case domainrequests.StatusAccepted:
		return "Solicitação aceita", "Seu pedido para " + serviceTitle + " foi aceito."
	case domainrequests.StatusRejected:
		return "Solicitação recusada", "O prestador não poderá atender " + serviceTitle + "."
	case domainrequests.StatusInProgress:
		return "Serviço iniciado", serviceTitle + " está em andamento."
	case domainrequests.StatusCompleted:
		return "Serviço concluído", serviceTitle + " foi marcado como concluído."
	case domainrequests.StatusNoShow:
		return "Ausência registrada", "A ausência no atendimento de " + serviceTitle + " foi registrada."
	default:
		return "Solicitação cancelada", "O pedido para " + serviceTitle + " foi cancelado."
	}
}
