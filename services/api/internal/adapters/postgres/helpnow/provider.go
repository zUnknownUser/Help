package helpnow

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

const presenceTTL = 90 * time.Second

func (repository *Repository) SetAvailability(ctx context.Context, uid string, input domainhelp.Availability, now time.Time) (domainhelp.Availability, error) {
	var providerID string
	err := repository.pool.QueryRow(ctx, `SELECT provider.id FROM providers provider
		WHERE provider.owner_uid=$1 AND provider.active AND provider.accepting_requests
		  AND provider.onboarding_status='approved' AND EXISTS(
			SELECT 1 FROM services service WHERE service.provider_id=provider.id
			  AND service.active AND service.deleted_at IS NULL
		  )`, uid).Scan(&providerID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainhelp.Availability{}, domainhelp.ErrProviderIneligible
	}
	if err != nil {
		return domainhelp.Availability{}, fmt.Errorf("validate help now provider: %w", err)
	}
	var availability domainhelp.Availability
	err = repository.pool.QueryRow(ctx, `INSERT INTO provider_help_now_availability(
		provider_id,enabled,latitude,longitude,max_distance_km,heartbeat_at,updated_at
	) VALUES($1,$2,$3,$4,$5,CASE WHEN $2 THEN $6::timestamptz ELSE NULL END,$6::timestamptz)
	ON CONFLICT(provider_id) DO UPDATE SET enabled=EXCLUDED.enabled,
		latitude=CASE WHEN EXCLUDED.enabled THEN EXCLUDED.latitude ELSE provider_help_now_availability.latitude END,
		longitude=CASE WHEN EXCLUDED.enabled THEN EXCLUDED.longitude ELSE provider_help_now_availability.longitude END,
		max_distance_km=EXCLUDED.max_distance_km,heartbeat_at=EXCLUDED.heartbeat_at,updated_at=EXCLUDED.updated_at
	RETURNING enabled,COALESCE(latitude,0),COALESCE(longitude,0),max_distance_km,
		COALESCE(heartbeat_at,'epoch'::timestamptz)`, providerID, input.Enabled,
		input.Latitude, input.Longitude, input.MaxDistanceKM, now).Scan(
		&availability.Enabled, &availability.Latitude, &availability.Longitude,
		&availability.MaxDistanceKM, &availability.HeartbeatAt)
	if err != nil {
		return domainhelp.Availability{}, fmt.Errorf("set help now availability: %w", err)
	}
	availability.ExpiresAt = availability.HeartbeatAt.Add(presenceTTL)
	return availability, nil
}

func (repository *Repository) GetAvailability(ctx context.Context, uid string, now time.Time) (domainhelp.Availability, error) {
	var availability domainhelp.Availability
	err := repository.pool.QueryRow(ctx, `SELECT COALESCE(availability.enabled AND availability.heartbeat_at>$2,false),
		COALESCE(availability.latitude,0),COALESCE(availability.longitude,0),COALESCE(availability.max_distance_km,10),
		COALESCE(availability.heartbeat_at,'epoch'::timestamptz)
	FROM providers provider LEFT JOIN provider_help_now_availability availability ON availability.provider_id=provider.id
	WHERE provider.owner_uid=$1`, uid, now.Add(-presenceTTL)).Scan(
		&availability.Enabled, &availability.Latitude, &availability.Longitude,
		&availability.MaxDistanceKM, &availability.HeartbeatAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainhelp.Availability{}, domainhelp.ErrProviderIneligible
	}
	if err != nil {
		return domainhelp.Availability{}, fmt.Errorf("get help now availability: %w", err)
	}
	availability.ExpiresAt = availability.HeartbeatAt.Add(presenceTTL)
	return availability, nil
}

func (repository *Repository) ListOffers(ctx context.Context, uid string, now time.Time) ([]domainhelp.Offer, error) {
	rows, err := repository.pool.Query(ctx, `SELECT offer.id::text,offer.request_id::text,
		request.category_id,category.name,request.note,
		concat_ws(' - ',NULLIF(split_part(request.formatted_address, ',', 3),''),
			NULLIF(split_part(request.formatted_address, ',', 4),'')),
		offer.distance_meters,offer.wave,offer.offered_at,offer.expires_at
	FROM help_now_offers offer
	JOIN providers provider ON provider.id=offer.provider_id AND provider.owner_uid=$1
	JOIN help_now_requests request ON request.id=offer.request_id AND request.status='searching'
	JOIN categories category ON category.id=request.category_id
	WHERE offer.status='offered' AND offer.expires_at>$2
	ORDER BY offer.offered_at DESC`, uid, now)
	if err != nil {
		return nil, fmt.Errorf("list help now offers: %w", err)
	}
	defer rows.Close()
	offers := make([]domainhelp.Offer, 0, 4)
	for rows.Next() {
		var offer domainhelp.Offer
		if err := rows.Scan(&offer.ID, &offer.RequestID, &offer.CategoryID, &offer.CategoryName,
			&offer.Note, &offer.Area, &offer.DistanceMeters, &offer.Wave,
			&offer.OfferedAt, &offer.ExpiresAt); err != nil {
			return nil, fmt.Errorf("scan help now offer: %w", err)
		}
		offers = append(offers, offer)
	}
	return offers, rows.Err()
}
