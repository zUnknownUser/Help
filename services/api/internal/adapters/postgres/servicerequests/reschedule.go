package servicerequests

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

func (repository *Repository) Reschedule(ctx context.Context, uid, requestID string, command domainrequests.Reschedule) (domainrequests.Request, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("begin service request reschedule: %w", err)
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, uid+":"+command.ClientID); err != nil {
		return domainrequests.Request{}, fmt.Errorf("lock reschedule command: %w", err)
	}
	var previousRequestID string
	var previousSchedule time.Time
	err = tx.QueryRow(ctx, `SELECT request_id::text,scheduled_for FROM service_request_reschedule_commands WHERE actor_uid=$1 AND client_command_id=$2::uuid`, uid, command.ClientID).Scan(&previousRequestID, &previousSchedule)
	if err == nil {
		if previousRequestID != requestID || !previousSchedule.Equal(command.ScheduledFor) {
			return domainrequests.Request{}, domainrequests.ErrIdempotencyConflict
		}
		request, loadErr := repository.scanRequest(tx.QueryRow(ctx, requestSelect+` WHERE request.id=$1::uuid AND request.customer_uid=$2`, requestID, uid))
		if loadErr != nil {
			return domainrequests.Request{}, loadErr
		}
		request.ViewerRole = domainrequests.ViewerCustomer
		return request, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, fmt.Errorf("find reschedule command: %w", err)
	}
	request, err := repository.scanRequest(tx.QueryRow(ctx, requestSelect+` WHERE request.id=$1::uuid FOR UPDATE OF request`, requestID))
	if errors.Is(err, pgx.ErrNoRows) {
		return domainrequests.Request{}, domainrequests.ErrNotFound
	}
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("lock rescheduled request: %w", err)
	}
	if request.CustomerUID != uid {
		return domainrequests.Request{}, domainrequests.ErrForbidden
	}
	if request.Status != domainrequests.StatusPending && request.Status != domainrequests.StatusAccepted {
		return domainrequests.Request{}, domainrequests.ErrInvalidTransition
	}
	if request.Version != command.ExpectedVersion {
		return domainrequests.Request{}, domainrequests.ErrVersionConflict
	}
	scheduledEnd, reservationEnd, err := validateReschedule(ctx, tx, request.ProviderID, request.ServiceID, command.ScheduledFor)
	if err != nil {
		return domainrequests.Request{}, err
	}
	_, err = tx.Exec(ctx, `UPDATE service_requests SET scheduled_for=$2,scheduled_end_at=$3,reservation_end_at=$4,status='pending',status_reason='Horário alterado pelo cliente',status_changed_at=now(),updated_at=now(),version=version+1 WHERE id=$1::uuid`, requestID, command.ScheduledFor, scheduledEnd, reservationEnd)
	if err != nil {
		var postgresError *pgconn.PgError
		if errors.As(err, &postgresError) && postgresError.Code == "23P01" {
			return domainrequests.Request{}, domainrequests.ErrSlotUnavailable
		}
		return domainrequests.Request{}, fmt.Errorf("update rescheduled request: %w", err)
	}
	if _, err = tx.Exec(ctx, `INSERT INTO service_request_reschedule_commands(actor_uid,client_command_id,request_id,scheduled_for,resulting_version) VALUES($1,$2::uuid,$3::uuid,$4,$5)`, uid, command.ClientID, requestID, command.ScheduledFor, request.Version+1); err != nil {
		return domainrequests.Request{}, fmt.Errorf("insert reschedule command: %w", err)
	}
	if _, err = tx.Exec(ctx, `DELETE FROM service_request_reminder_dispatches WHERE request_id=$1::uuid`, requestID); err != nil {
		return domainrequests.Request{}, fmt.Errorf("reset request reminders: %w", err)
	}
	if _, err = tx.Exec(ctx, `WITH notification AS (INSERT INTO notifications(firebase_uid,title,body,kind,data) VALUES($1,'Novo horário solicitado',$2,'service_request',jsonb_build_object('request_id',$3::text,'service_id',$4::text,'status','pending','route','service_request')) RETURNING id) INSERT INTO notification_push_outbox(notification_id) SELECT id FROM notification`, request.ProviderUID, "O cliente alterou o horário de "+request.ServiceTitle+". Confirme novamente.", requestID, request.ServiceID); err != nil {
		return domainrequests.Request{}, fmt.Errorf("enqueue reschedule notification: %w", err)
	}
	updated, err := repository.scanRequest(tx.QueryRow(ctx, requestSelect+` WHERE request.id=$1::uuid`, requestID))
	if err != nil {
		return domainrequests.Request{}, fmt.Errorf("load rescheduled request: %w", err)
	}
	updated.ViewerRole = domainrequests.ViewerCustomer
	if err := tx.Commit(ctx); err != nil {
		return domainrequests.Request{}, fmt.Errorf("commit service request reschedule: %w", err)
	}
	return updated, nil
}

func validateReschedule(ctx context.Context, tx pgx.Tx, providerID, serviceID string, scheduledFor time.Time) (time.Time, time.Time, error) {
	var duration, buffer, notice, horizon, interval int
	var zone string
	err := tx.QueryRow(ctx, `SELECT service.duration_minutes,setting.buffer_minutes,setting.minimum_notice_minutes,setting.booking_horizon_days,setting.slot_interval_minutes,setting.time_zone FROM services service JOIN provider_schedule_settings setting ON setting.provider_id=service.provider_id WHERE service.id=$1 AND service.provider_id=$2 AND service.active AND service.deleted_at IS NULL`, serviceID, providerID).Scan(&duration, &buffer, &notice, &horizon, &interval, &zone)
	if errors.Is(err, pgx.ErrNoRows) {
		return time.Time{}, time.Time{}, domainrequests.ErrServiceUnavailable
	}
	if err != nil {
		return time.Time{}, time.Time{}, fmt.Errorf("load reschedule policy: %w", err)
	}
	location, err := time.LoadLocation(zone)
	if err != nil {
		return time.Time{}, time.Time{}, fmt.Errorf("load reschedule timezone: %w", err)
	}
	local := scheduledFor.In(location)
	minute := local.Hour()*60 + local.Minute()
	var valid bool
	end := scheduledFor.Add(time.Duration(duration) * time.Minute)
	reservedUntil := end.Add(time.Duration(buffer) * time.Minute)
	err = tx.QueryRow(ctx, `SELECT $1>=now()+make_interval(mins=>$6) AND $1<=now()+make_interval(days=>$7) AND EXISTS(SELECT 1 FROM provider_availability_rules WHERE provider_id=$2 AND weekday=$3 AND start_minute<=$4 AND end_minute>=$4+$5 AND (($4-start_minute)%$8)=0) AND NOT EXISTS(SELECT 1 FROM provider_schedule_blocks WHERE provider_id=$2 AND tstzrange(starts_at,ends_at,'[)')&&tstzrange($1,$9,'[)'))`, scheduledFor, providerID, int(local.Weekday()), minute, duration, notice, horizon, interval, reservedUntil).Scan(&valid)
	if err != nil {
		return time.Time{}, time.Time{}, fmt.Errorf("validate reschedule slot: %w", err)
	}
	if !valid {
		return time.Time{}, time.Time{}, domainrequests.ErrSlotUnavailable
	}
	return end, reservedUntil, nil
}
