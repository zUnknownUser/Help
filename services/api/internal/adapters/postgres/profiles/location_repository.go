package profiles

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type LocationRepository struct{ pool *pgxpool.Pool }

func NewLocationRepository(pool *pgxpool.Pool) *LocationRepository {
	return &LocationRepository{pool: pool}
}

func (repository *LocationRepository) SaveDefault(
	ctx context.Context,
	uid string,
	location domainprofiles.Location,
) error {
	_, err := repository.pool.Exec(ctx, `
		INSERT INTO user_addresses (
		  firebase_uid, label, formatted_address, postal_code, street,
		  street_number, complement, district, city, state, latitude, longitude, is_default
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, true)
		ON CONFLICT (firebase_uid) WHERE is_default AND active DO UPDATE SET
			label = EXCLUDED.label,
			formatted_address = EXCLUDED.formatted_address,
			postal_code = EXCLUDED.postal_code,
			street = EXCLUDED.street,
			street_number = EXCLUDED.street_number,
			complement = EXCLUDED.complement,
			district = EXCLUDED.district,
			city = EXCLUDED.city,
			state = EXCLUDED.state,
			latitude = EXCLUDED.latitude,
			longitude = EXCLUDED.longitude,
			updated_at = now()`, uid, location.Label, location.Address,
		location.PostalCode, location.Street, location.StreetNumber, location.Complement,
		location.District, location.City, location.State, location.Latitude, location.Longitude)
	if err != nil {
		return fmt.Errorf("upsert default location: %w", err)
	}
	return nil
}
