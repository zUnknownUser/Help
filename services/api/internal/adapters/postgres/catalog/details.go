package catalog

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	domaincatalog "github.com/vendlydigital/help/services/api/internal/domain/catalog"
)

func (repository *Repository) FindDetails(
	ctx context.Context,
	uid, serviceID string,
) (domaincatalog.Details, error) {
	var details domaincatalog.Details
	var addressLabel, formattedAddress *string
	var addressLatitude, addressLongitude *float64
	err := repository.pool.QueryRow(ctx, `
		SELECT service.id, service.provider_id, COALESCE(service.category_id, ''),
		       service.title, service.description, service.rating::float8, service.reviews,
		       service.duration_minutes, service.price_cents, service.old_price_cents,
		       service.image_url, service.image_alignment, service.badge,
		       service.active, service.published_at, service.created_at, service.updated_at,
		       provider.name, provider.verified, provider.owner_uid,
		       concat_ws(' - ', NULLIF(provider_address.city, ''), NULLIF(provider_address.state, '')),
		       CASE WHEN viewer_address.latitude IS NULL OR provider_address.latitude IS NULL THEN NULL ELSE
		         6371 * acos(LEAST(1, GREATEST(-1,
		           cos(radians(viewer_address.latitude)) * cos(radians(provider_address.latitude)) *
		           cos(radians(provider_address.longitude) - radians(viewer_address.longitude)) +
		           sin(radians(viewer_address.latitude)) * sin(radians(provider_address.latitude))
		         )))
		       END,
		       viewer_address.label, viewer_address.formatted_address,
		       viewer_address.latitude, viewer_address.longitude,
		       CASE
		         WHEN NOT EXISTS (SELECT 1 FROM user_roles WHERE firebase_uid = $1 AND role = 'customer') THEN 'customer_role_required'
		         WHEN provider.owner_uid = $1 THEN 'own_service'
		         WHEN viewer_address.id IS NULL OR viewer_address.latitude IS NULL THEN 'address_required'
		         ELSE ''
		       END
		FROM services service
		JOIN providers provider ON provider.id = service.provider_id
		  AND provider.active AND provider.accepting_requests
		  AND provider.onboarding_status = 'approved' AND provider.owner_uid IS NOT NULL
		LEFT JOIN user_addresses provider_address
		  ON provider_address.firebase_uid = provider.owner_uid
		 AND provider_address.is_default AND provider_address.active
		LEFT JOIN user_addresses viewer_address
		  ON viewer_address.firebase_uid = $1
		 AND viewer_address.is_default AND viewer_address.active
		WHERE service.id = $2 AND service.active AND service.deleted_at IS NULL`, uid, serviceID).Scan(
		&details.Service.ID, &details.Service.ProviderID, &details.Service.CategoryID,
		&details.Service.Title, &details.Service.Description, &details.Service.Rating,
		&details.Service.Reviews, &details.Service.DurationMinutes, &details.Service.PriceCents,
		&details.Service.OldPriceCents, &details.Service.ImageURL, &details.Service.ImageAlignment,
		&details.Service.Badge, &details.Service.Active, &details.Service.PublishedAt,
		&details.Service.CreatedAt, &details.Service.UpdatedAt, &details.ProviderName,
		&details.ProviderVerified, &details.ProviderUserID, &details.ServiceArea,
		&details.Service.DistanceKM, &addressLabel, &formattedAddress,
		&addressLatitude, &addressLongitude, &details.RequestBlockedReason,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domaincatalog.Details{}, domaincatalog.ErrServiceNotFound
	}
	if err != nil {
		return domaincatalog.Details{}, fmt.Errorf("query service details: %w", err)
	}
	if addressLabel != nil && formattedAddress != nil && addressLatitude != nil && addressLongitude != nil {
		details.ViewerAddress = &domaincatalog.ViewerAddress{
			Label: *addressLabel, FormattedAddress: *formattedAddress,
			Latitude: *addressLatitude, Longitude: *addressLongitude,
		}
	}
	details.CanRequest = details.RequestBlockedReason == ""
	return details, nil
}
