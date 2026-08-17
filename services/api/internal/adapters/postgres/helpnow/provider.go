package helpnow

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/vendlydigital/help/services/api/internal/database"
	domainhelp "github.com/vendlydigital/help/services/api/internal/domain/helpnow"
)

const presenceTTL = 90 * time.Second

func (repository *Repository) SetAvailability(ctx context.Context, uid string, input domainhelp.Availability, now time.Time) (domainhelp.Availability, error) {
	var providerID string
	query, args, buildErr := database.Query.Select("provider.id").From("providers provider").
		Where("provider.owner_uid = ?", uid).Where("provider.active").Where("provider.accepting_requests").
		Where("provider.onboarding_status = ?", "approved").
		Where(`EXISTS(SELECT 1 FROM services service WHERE service.provider_id=provider.id
			AND service.active AND service.deleted_at IS NULL)`).ToSql()
	if buildErr != nil {
		return domainhelp.Availability{}, fmt.Errorf("build help now provider validation: %w", buildErr)
	}
	err := repository.pool.QueryRow(ctx, query, args...).Scan(&providerID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domainhelp.Availability{}, domainhelp.ErrProviderIneligible
	}
	if err != nil {
		return domainhelp.Availability{}, fmt.Errorf("validate help now provider: %w", err)
	}
	var availability domainhelp.Availability
	query, args, buildErr = database.Query.Insert("provider_help_now_availability").
		Columns("provider_id", "enabled", "latitude", "longitude", "max_distance_km", "heartbeat_at", "updated_at").
		Values(providerID, input.Enabled, input.Latitude, input.Longitude, input.MaxDistanceKM,
			database.Expr("CASE WHEN ? THEN ?::timestamptz ELSE NULL END", input.Enabled, now), now).
		Suffix(`ON CONFLICT(provider_id) DO UPDATE SET enabled=EXCLUDED.enabled,
		latitude=CASE WHEN EXCLUDED.enabled THEN EXCLUDED.latitude ELSE provider_help_now_availability.latitude END,
		longitude=CASE WHEN EXCLUDED.enabled THEN EXCLUDED.longitude ELSE provider_help_now_availability.longitude END,
		max_distance_km=EXCLUDED.max_distance_km,heartbeat_at=EXCLUDED.heartbeat_at,updated_at=EXCLUDED.updated_at
	RETURNING enabled,COALESCE(latitude,0),COALESCE(longitude,0),max_distance_km,
		COALESCE(heartbeat_at,'epoch'::timestamptz)`).ToSql()
	if buildErr != nil {
		return domainhelp.Availability{}, fmt.Errorf("build help now availability upsert: %w", buildErr)
	}
	err = repository.pool.QueryRow(ctx, query, args...).Scan(
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
	query, args, buildErr := database.Query.Select().
		Column("COALESCE(availability.enabled AND availability.heartbeat_at>?,false)", now.Add(-presenceTTL)).
		Columns("COALESCE(availability.latitude,0)", "COALESCE(availability.longitude,0)",
			"COALESCE(availability.max_distance_km,10)", "COALESCE(availability.heartbeat_at,'epoch'::timestamptz)",
		).From("providers provider").LeftJoin("provider_help_now_availability availability ON availability.provider_id=provider.id").
		Where("provider.owner_uid = ?", uid).ToSql()
	if buildErr != nil {
		return domainhelp.Availability{}, fmt.Errorf("build help now availability query: %w", buildErr)
	}
	err := repository.pool.QueryRow(ctx, query, args...).Scan(
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
	query, args, buildErr := database.Query.Select(`offer.id::text`, `offer.request_id::text`,
		`COALESCE(request.category_id,'')`, `COALESCE(category.name,'Ajuda geral')`, `request.note`,
		`concat_ws(' - ',NULLIF(split_part(request.formatted_address, ',', 3),''),
			NULLIF(split_part(request.formatted_address, ',', 4),''))`,
		`offer.distance_meters`, `offer.wave`, `offer.offered_at`, `offer.expires_at`).
		From("help_now_offers offer").
		Join("providers provider ON provider.id=offer.provider_id").
		Join("help_now_requests request ON request.id=offer.request_id AND request.status='searching'").
		LeftJoin("categories category ON category.id=request.category_id").
		Where("provider.owner_uid = ?", uid).Where("offer.status = ?", "offered").
		Where("offer.expires_at > ?", now).OrderBy("offer.offered_at DESC").ToSql()
	if buildErr != nil {
		return nil, fmt.Errorf("build help now offers: %w", buildErr)
	}
	rows, err := repository.pool.Query(ctx, query, args...)
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
