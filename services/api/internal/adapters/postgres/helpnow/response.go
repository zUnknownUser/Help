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

func (repository *Repository) Respond(ctx context.Context, uid string, command domainhelp.Command, now time.Time) (domainhelp.Request, []string, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("begin help now response: %w", err)
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, uid+":"+command.ClientID); err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("lock help now command: %w", err)
	}
	var previousOffer, previousAction, previousRequest string
	err = tx.QueryRow(ctx, `SELECT offer_id::text,action,request_id::text FROM help_now_offer_commands
		WHERE actor_uid=$1 AND client_command_id=$2::uuid`, uid, command.ClientID).Scan(
		&previousOffer, &previousAction, &previousRequest)
	if err == nil {
		if previousOffer != command.OfferID || previousAction != command.Action {
			return domainhelp.Request{}, nil, domainhelp.ErrIdempotency
		}
		request, loadErr := scanRequest(tx.QueryRow(ctx, requestSelect+` WHERE request.id=$1::uuid`, previousRequest))
		return request, nil, loadErr
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return domainhelp.Request{}, nil, fmt.Errorf("find help now command: %w", err)
	}
	var offerStatus, requestID, requestStatus, providerID, customerID string
	var expiresAt time.Time
	err = tx.QueryRow(ctx, `SELECT offer.status,offer.expires_at,request.id::text,request.status,
		offer.provider_id,request.customer_uid
	FROM help_now_offers offer
	JOIN help_now_requests request ON request.id=offer.request_id
	JOIN providers provider ON provider.id=offer.provider_id AND provider.owner_uid=$2
	WHERE offer.id=$1::uuid FOR UPDATE OF request,offer`, command.OfferID, uid).Scan(
		&offerStatus, &expiresAt, &requestID, &requestStatus, &providerID, &customerID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainhelp.Request{}, nil, domainhelp.ErrNotFound
	}
	if err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("lock help now offer: %w", err)
	}
	if requestStatus != string(domainhelp.StatusSearching) {
		return domainhelp.Request{}, nil, domainhelp.ErrAlreadyAssigned
	}
	if offerStatus != "offered" || !expiresAt.After(now) {
		return domainhelp.Request{}, nil, domainhelp.ErrOfferExpired
	}
	if command.Action == "decline" {
		if _, err = tx.Exec(ctx, `UPDATE help_now_offers SET status='declined',responded_at=$2 WHERE id=$1::uuid`, command.OfferID, now); err != nil {
			return domainhelp.Request{}, nil, fmt.Errorf("decline help now offer: %w", err)
		}
		if _, err = tx.Exec(ctx, `INSERT INTO help_now_offer_commands(actor_uid,client_command_id,offer_id,action,request_id)
			VALUES($1,$2::uuid,$3::uuid,'decline',$4::uuid)`, uid, command.ClientID, command.OfferID, requestID); err != nil {
			return domainhelp.Request{}, nil, fmt.Errorf("record help now decline: %w", err)
		}
		request, err := scanRequest(tx.QueryRow(ctx, requestSelect+` WHERE request.id=$1::uuid`, requestID))
		if err == nil {
			err = tx.Commit(ctx)
		}
		return request, nil, err
	}
	return repository.accept(ctx, tx, uid, command, requestID, providerID, customerID, now)
}

func (repository *Repository) accept(ctx context.Context, tx pgx.Tx, uid string, command domainhelp.Command, requestID, providerID, customerID string, now time.Time) (domainhelp.Request, []string, error) {
	var serviceID string
	var durationMinutes, bufferMinutes, priceCents int
	err := tx.QueryRow(ctx, `SELECT service.id,service.duration_minutes,setting.buffer_minutes,service.price_cents
		FROM help_now_requests request
		JOIN services service ON service.provider_id=$2 AND service.category_id=request.category_id
		  AND service.active AND service.deleted_at IS NULL
		JOIN providers provider ON provider.id=service.provider_id AND provider.active
		  AND provider.accepting_requests AND provider.onboarding_status='approved'
		JOIN provider_schedule_settings setting ON setting.provider_id=provider.id
		JOIN provider_help_now_availability availability ON availability.provider_id=provider.id
		  AND availability.enabled AND availability.heartbeat_at>$3
		WHERE request.id=$1::uuid
		ORDER BY service.price_cents,service.updated_at DESC LIMIT 1 FOR SHARE OF service,provider`,
		requestID, providerID, now.Add(-presenceTTL)).Scan(&serviceID, &durationMinutes, &bufferMinutes, &priceCents)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainhelp.Request{}, nil, domainhelp.ErrProviderIneligible
	}
	if err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("select help now service: %w", err)
	}
	scheduledEnd := now.Add(time.Duration(durationMinutes) * time.Minute)
	reservationEnd := scheduledEnd.Add(time.Duration(bufferMinutes) * time.Minute)
	var serviceRequestID string
	err = tx.QueryRow(ctx, `INSERT INTO service_requests(
		service_id,provider_id,customer_uid,client_request_id,status,note,scheduled_for,
		scheduled_end_at,reservation_end_at,quoted_price_cents,address_label,formatted_address,
		postal_code,street,street_number,complement,district,city,state,latitude,longitude,status_changed_at
	) SELECT $2,$3,request.customer_uid,request.client_request_id,'accepted',request.note,$4,$5,$6,$7,
		request.address_label,request.formatted_address,'','','','','','','',request.latitude,request.longitude,$4
	FROM help_now_requests request WHERE request.id=$1::uuid RETURNING id::text`, requestID,
		serviceID, providerID, now, scheduledEnd, reservationEnd, priceCents).Scan(&serviceRequestID)
	if err != nil {
		var postgresError *pgconn.PgError
		if errors.As(err, &postgresError) && postgresError.Code == "23P01" {
			return domainhelp.Request{}, nil, domainhelp.ErrProviderBusy
		}
		return domainhelp.Request{}, nil, fmt.Errorf("create urgent service request: %w", err)
	}
	if _, err = tx.Exec(ctx, `UPDATE help_now_requests SET status='assigned',assigned_provider_id=$2,
		service_request_id=$3::uuid,updated_at=$4 WHERE id=$1::uuid`, requestID, providerID,
		serviceRequestID, now); err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("assign help now request: %w", err)
	}
	if _, err = tx.Exec(ctx, `UPDATE help_now_offers SET status=CASE WHEN id=$2::uuid THEN 'accepted' ELSE 'lost' END,
		responded_at=$3 WHERE request_id=$1::uuid AND status='offered'`, requestID, command.OfferID, now); err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("close help now offers: %w", err)
	}
	if _, err = tx.Exec(ctx, `INSERT INTO help_now_offer_commands(actor_uid,client_command_id,offer_id,action,request_id,service_request_id)
		VALUES($1,$2::uuid,$3::uuid,'accept',$4::uuid,$5::uuid)`, uid, command.ClientID,
		command.OfferID, requestID, serviceRequestID); err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("record help now acceptance: %w", err)
	}
	if _, err = tx.Exec(ctx, `WITH notification AS (
		INSERT INTO notifications(firebase_uid,title,body,kind,data)
		VALUES($1,'Profissional encontrado','Um profissional aceitou seu Help Agora.','help_now_assigned',
			jsonb_build_object('help_now_request_id',$2::text,'request_id',$3::text,'route','help_now')) RETURNING id
	) INSERT INTO notification_push_outbox(notification_id) SELECT id FROM notification`,
		customerID, requestID, serviceRequestID); err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("notify help now customer: %w", err)
	}
	rows, err := tx.Query(ctx, `SELECT provider.owner_uid FROM help_now_offers offer
		JOIN providers provider ON provider.id=offer.provider_id
		WHERE offer.request_id=$1::uuid AND offer.id<>$2::uuid`, requestID, command.OfferID)
	if err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("load help now losers: %w", err)
	}
	losers := make([]string, 0, 4)
	for rows.Next() {
		var recipient string
		if err := rows.Scan(&recipient); err != nil {
			rows.Close()
			return domainhelp.Request{}, nil, err
		}
		losers = append(losers, recipient)
	}
	rows.Close()
	request, err := scanRequest(tx.QueryRow(ctx, requestSelect+` WHERE request.id=$1::uuid`, requestID))
	if err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("load assigned help now request: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domainhelp.Request{}, nil, fmt.Errorf("commit help now assignment: %w", err)
	}
	return request, losers, nil
}
