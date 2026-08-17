package servicerequests

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

func (repository *Repository) FindByClientID(
	ctx context.Context,
	uid, clientID string,
) (domainrequests.Request, error) {
	request, err := repository.scanRequest(repository.pool.QueryRow(ctx, requestSelect+`
		WHERE request.customer_uid = $1 AND request.client_request_id = $2::uuid`, uid, clientID))
	if errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, domainrequests.ErrNotFound
	}
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("find service request by client id: %w", err)
	}
	return request, nil
}

func (repository *Repository) Create(
	ctx context.Context,
	uid, serviceID string,
	draft domainrequests.Draft,
) (domainrequests.Request, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("begin service request: %w", err)
	}
	defer tx.Rollback(ctx)

	var providerID, providerUID, serviceTitle, providerName string
	var priceCents, durationMinutes, bufferMinutes, noticeMinutes, horizonDays, slotInterval int
	var timeZone string
	err = tx.QueryRow(ctx, `
		SELECT service.provider_id, provider.owner_uid, service.title, provider.name,
		       service.price_cents, service.duration_minutes, setting.buffer_minutes,
		       setting.minimum_notice_minutes, setting.booking_horizon_days,
		       setting.slot_interval_minutes, setting.time_zone
		FROM services service
		JOIN providers provider ON provider.id = service.provider_id
		  AND provider.active AND provider.accepting_requests
		  AND provider.onboarding_status = 'approved' AND provider.owner_uid IS NOT NULL
		JOIN provider_schedule_settings setting ON setting.provider_id = provider.id
		WHERE service.id = $1 AND service.active AND service.deleted_at IS NULL
		FOR SHARE OF service, provider`, serviceID).Scan(
		&providerID, &providerUID, &serviceTitle, &providerName, &priceCents,
		&durationMinutes, &bufferMinutes, &noticeMinutes, &horizonDays, &slotInterval, &timeZone,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, domainrequests.ErrServiceUnavailable
	}
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("load requested service: %w", err)
	}
	if providerUID == uid {
		return domainrequests.Request{}, domainrequests.ErrOwnService
	}
	var hasCustomerRole bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS (
		SELECT 1 FROM user_roles WHERE firebase_uid = $1 AND role = 'customer'
	)`, uid).Scan(&hasCustomerRole); err != nil {
		return domainrequests.Request{}, fmt.Errorf("check customer role: %w", err)
	}
	if !hasCustomerRole {
		return domainrequests.Request{}, domainrequests.ErrCustomerRequired
	}
	location, err := time.LoadLocation(timeZone)
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("load provider timezone: %w", err)
	}
	localSchedule := draft.ScheduledFor.In(location)
	minute := localSchedule.Hour()*60 + localSchedule.Minute()
	var matchesRule, validWindow bool
	err = tx.QueryRow(ctx, `SELECT EXISTS(
		SELECT 1 FROM provider_availability_rules
		WHERE provider_id=$1 AND weekday=$2 AND start_minute<=$3
		  AND end_minute>=$3+$4 AND (($3-start_minute)%$5)=0
	)`, providerID, int(localSchedule.Weekday()), minute, durationMinutes, slotInterval).Scan(&matchesRule)
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("validate schedule rule: %w", err)
	}
	scheduledEnd := draft.ScheduledFor.Add(time.Duration(durationMinutes) * time.Minute)
	reservationEnd := scheduledEnd.Add(time.Duration(bufferMinutes) * time.Minute)
	err = tx.QueryRow(ctx, `SELECT
		$1 >= now()+make_interval(mins=>$3)
		AND $1 <= now()+make_interval(days=>$4)
		AND NOT EXISTS(
			SELECT 1 FROM provider_schedule_blocks
			WHERE provider_id=$2
			  AND tstzrange(starts_at,ends_at,'[)') && tstzrange($1,$5,'[)')
		)`, draft.ScheduledFor, providerID, noticeMinutes, horizonDays, reservationEnd).Scan(&validWindow)
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("validate schedule window: %w", err)
	}
	if !matchesRule || !validWindow {
		return domainrequests.Request{}, domainrequests.ErrSlotUnavailable
	}

	var requestID string
	err = tx.QueryRow(ctx, `
		INSERT INTO service_requests (
			service_id, provider_id, customer_uid, client_request_id, note,
			scheduled_for, scheduled_end_at, reservation_end_at, quoted_price_cents,
			address_label, formatted_address,
			postal_code, street, street_number, complement, district, city, state,
			latitude, longitude
		)
		SELECT $1, $2, $3, $4::uuid, $5, $6, $7, $8, $9, address.label,
		       address.formatted_address, address.postal_code, address.street,
		       address.street_number, address.complement, address.district,
		       address.city, address.state, address.latitude, address.longitude
		FROM user_addresses address
		WHERE address.firebase_uid = $3 AND address.is_default AND address.active
		  AND address.latitude IS NOT NULL
		ON CONFLICT (customer_uid, client_request_id) DO NOTHING
		RETURNING id::text`, serviceID, providerID, uid, draft.ClientID, draft.Note,
		draft.ScheduledFor, scheduledEnd, reservationEnd, priceCents).Scan(&requestID)
	if errors.Is(err, pgx.ErrNoRows) {
		existing, loadErr := repository.scanRequest(tx.QueryRow(ctx, requestSelect+`
			WHERE request.customer_uid = $1 AND request.client_request_id = $2::uuid`, uid, draft.ClientID))
		if loadErr == nil {
			if !draft.SameIntent(serviceID, existing) {
				return domainrequests.Request{}, domainrequests.ErrIdempotencyConflict
			}
			return existing, nil
		}
		if errors.Is(loadErr, pgx.ErrNoRows) {
			return domainrequests.Request{}, domainrequests.ErrAddressRequired
		}
		return domainrequests.Request{}, fmt.Errorf("load concurrent service request: %w", loadErr)
	}
	if err != nil {
		var postgresError *pgconn.PgError
		if errors.As(err, &postgresError) && postgresError.Code == "23P01" {
			return domainrequests.Request{}, domainrequests.ErrSlotUnavailable
		}
		return domainrequests.Request{}, fmt.Errorf("insert service request: %w", err)
	}
	_, err = tx.Exec(ctx, `
		WITH notification AS (
			INSERT INTO notifications (firebase_uid, title, body, kind, data)
			VALUES ($1, 'Nova solicitação de serviço', $2, 'service_request',
			        jsonb_build_object('request_id', $3::text, 'service_id', $4::text, 'route', 'service_request'))
			RETURNING id
		)
		INSERT INTO notification_push_outbox (notification_id)
		SELECT id FROM notification`,
		providerUID, "Uma nova solicitação chegou para "+serviceTitle+".", requestID, serviceID)
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("insert service request notification: %w", err)
	}
	request, err := repository.scanRequest(tx.QueryRow(ctx, requestSelect+` WHERE request.id = $1::uuid`, requestID))
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("load created service request: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domainrequests.Request{}, fmt.Errorf("commit service request: %w", err)
	}
	return request, nil
}

const requestSelect = `
	SELECT request.id::text, request.client_request_id::text, request.service_id,
	       service.title, request.provider_id, provider.owner_uid, provider.name,
	       request.customer_uid, customer.display_name, request.status, request.note,
	       request.scheduled_for, request.scheduled_end_at, request.quoted_price_cents,
	       request.address_label, request.formatted_address, request.latitude,
	       request.longitude, request.created_at, request.updated_at, request.version,
	       request.status_reason
	FROM service_requests request
	JOIN services service ON service.id = request.service_id
	JOIN providers provider ON provider.id = request.provider_id
	JOIN user_profiles customer ON customer.firebase_uid = request.customer_uid
`

type rowScanner interface{ Scan(...any) error }

func (repository *Repository) scanRequest(row rowScanner) (domainrequests.Request, error) {
	var request domainrequests.Request
	var latitude, longitude sql.NullFloat64
	err := row.Scan(
		&request.ID, &request.ClientID, &request.ServiceID, &request.ServiceTitle,
		&request.ProviderID, &request.ProviderUID, &request.ProviderName,
		&request.CustomerUID, &request.CustomerName,
		&request.Status, &request.Note, &request.ScheduledFor, &request.ScheduledEnd,
		&request.QuotedPriceCents,
		&request.AddressLabel, &request.Address, &latitude, &longitude,
		&request.CreatedAt, &request.UpdatedAt, &request.Version, &request.StatusReason,
	)
	if err != nil {
		return domainrequests.Request{}, err
	}
	request.Latitude, request.Longitude = latitude.Float64, longitude.Float64
	request.ViewerRole = domainrequests.ViewerCustomer
	return request, nil
}
