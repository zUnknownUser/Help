package helpnow

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

const offerTTL = 25 * time.Second

func (repository *Repository) DispatchDue(ctx context.Context, now time.Time, limit int) ([]domainhelp.DispatchEvent, error) {
	tx, err := repository.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin help now dispatch: %w", err)
	}
	defer tx.Rollback(ctx)
	query, args, buildErr := database.Query.Select("id::text", "customer_uid", "search_wave", "search_expires_at").
		From("help_now_requests").Where("status = ?", "searching").Where("next_dispatch_at <= ?", now).
		OrderBy("next_dispatch_at", "id").Limit(uint64(limit)).Suffix("FOR UPDATE SKIP LOCKED").ToSql()
	if buildErr != nil {
		return nil, fmt.Errorf("build help now dispatch claim: %w", buildErr)
	}
	rows, err := tx.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("claim help now dispatches: %w", err)
	}
	type due struct {
		id, customer string
		wave         int
		expires      time.Time
	}
	dueRequests := make([]due, 0, limit)
	for rows.Next() {
		var item due
		if err := rows.Scan(&item.id, &item.customer, &item.wave, &item.expires); err != nil {
			rows.Close()
			return nil, err
		}
		dueRequests = append(dueRequests, item)
	}
	rows.Close()
	events := make([]domainhelp.DispatchEvent, 0, limit*4)
	for _, item := range dueRequests {
		if !item.expires.After(now) || item.wave >= 3 {
			if err := repository.finishWithoutProvider(ctx, tx, item.id, item.customer, now); err != nil {
				return nil, err
			}
			events = append(events, domainhelp.DispatchEvent{UserID: item.customer, Type: "help_now.updated", RequestID: item.id})
			continue
		}
		wave := item.wave + 1
		radiusKM := []int{5, 10, 20}[wave-1]
		offerEvents, err := repository.offerWave(ctx, tx, item.id, wave, radiusKM, now)
		if err != nil {
			return nil, err
		}
		events = append(events, offerEvents...)
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit help now dispatch: %w", err)
	}
	return events, nil
}

func (repository *Repository) offerWave(ctx context.Context, tx pgx.Tx, requestID string, wave, radiusKM int, now time.Time) ([]domainhelp.DispatchEvent, error) {
	rows, err := tx.Query(ctx, `WITH distances AS (
		SELECT provider.id AS provider_id,provider.owner_uid,availability.max_distance_km,
			(6371000*acos(LEAST(1,GREATEST(-1,
				cos(radians(request.latitude))*cos(radians(availability.latitude))*
				cos(radians(availability.longitude)-radians(request.longitude))+
				sin(radians(request.latitude))*sin(radians(availability.latitude))
			))))::integer AS distance_meters
		FROM help_now_requests request
		JOIN provider_help_now_availability availability ON availability.enabled
		  AND availability.heartbeat_at>$4::timestamptz-interval '90 seconds'
		JOIN providers provider ON provider.id=availability.provider_id AND provider.active
		  AND provider.accepting_requests AND provider.onboarding_status='approved'
		WHERE request.id=$1::uuid AND provider.owner_uid<>request.customer_uid
		  AND EXISTS(SELECT 1 FROM services service WHERE service.provider_id=provider.id
			AND (request.category_id IS NULL OR service.category_id=request.category_id)
			AND service.active AND service.deleted_at IS NULL)
		  AND NOT EXISTS(SELECT 1 FROM help_now_offers old
			WHERE old.request_id=request.id AND old.provider_id=provider.id)
	), candidates AS (
		SELECT * FROM distances WHERE distance_meters<=LEAST($3,max_distance_km)*1000
		ORDER BY distance_meters,provider_id LIMIT 5
	), inserted AS (
		INSERT INTO help_now_offers(request_id,provider_id,wave,distance_meters,offered_at,expires_at)
		SELECT $1::uuid,provider_id,$2,distance_meters,$4,$4+interval '25 seconds' FROM candidates
		RETURNING id,provider_id
	), created_notifications AS (
		INSERT INTO notifications(firebase_uid,title,body,kind,data)
		SELECT provider.owner_uid,'Novo Help Agora','Um cliente próximo precisa de atendimento.','help_now_offer',
			jsonb_build_object('help_now_offer_id',inserted.id::text,'help_now_request_id',$1::text,'route','help_now_offer')
		FROM inserted JOIN providers provider ON provider.id=inserted.provider_id
		RETURNING id
	), queued AS (
		INSERT INTO notification_push_outbox(notification_id) SELECT id FROM created_notifications
	)
	SELECT inserted.id::text,provider.owner_uid FROM inserted
	JOIN providers provider ON provider.id=inserted.provider_id`, requestID, wave, radiusKM, now)
	if err != nil {
		return nil, fmt.Errorf("create help now offer wave: %w", err)
	}
	events := make([]domainhelp.DispatchEvent, 0, 5)
	for rows.Next() {
		var offerID, userID string
		if err := rows.Scan(&offerID, &userID); err != nil {
			rows.Close()
			return nil, err
		}
		events = append(events, domainhelp.DispatchEvent{UserID: userID, Type: "help_now.offer", RequestID: requestID, OfferID: offerID})
	}
	rows.Close()
	query, args, buildErr := database.Query.Update("help_now_requests").SetMap(map[string]any{
		"search_wave": wave, "next_dispatch_at": now.Add(offerTTL), "updated_at": now,
	}).Where("id = ?::uuid", requestID).ToSql()
	if buildErr != nil {
		return nil, fmt.Errorf("build help now wave update: %w", buildErr)
	}
	_, err = tx.Exec(ctx, query, args...)
	return events, err
}

func (repository *Repository) finishWithoutProvider(ctx context.Context, tx pgx.Tx, requestID, customerID string, now time.Time) error {
	query, args, buildErr := database.Query.Update("help_now_requests").Set("status", "no_provider").Set("updated_at", now).
		Where("id = ?::uuid", requestID).ToSql()
	if buildErr != nil {
		return fmt.Errorf("build help now finish: %w", buildErr)
	}
	if _, err := tx.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("finish help now search: %w", err)
	}
	query, args, buildErr = database.Query.Update("help_now_offers").Set("status", "expired").
		Where("request_id = ?::uuid", requestID).Where("status = ?", "offered").ToSql()
	if buildErr != nil {
		return fmt.Errorf("build help now offer expiry: %w", buildErr)
	}
	if _, err := tx.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("expire help now offers: %w", err)
	}
	_, err := tx.Exec(ctx, `WITH notification AS (
			INSERT INTO notifications(firebase_uid,title,body,kind,data)
			VALUES($2,'Nenhum profissional disponível','Não encontramos atendimento imediato agora.','help_now_no_provider',
				jsonb_build_object('help_now_request_id',$1::text,'route','help_now')) RETURNING id
		) INSERT INTO notification_push_outbox(notification_id) SELECT id FROM notification`, requestID, customerID)
	if err != nil {
		return fmt.Errorf("finish help now search: %w", err)
	}
	return nil
}
