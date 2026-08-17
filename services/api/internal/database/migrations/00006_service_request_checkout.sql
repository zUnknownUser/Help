-- +goose Up
ALTER TABLE service_requests
    ADD COLUMN client_request_id uuid,
    ADD COLUMN quoted_price_cents integer,
    ADD COLUMN address_label text NOT NULL DEFAULT '',
    ADD COLUMN formatted_address text NOT NULL DEFAULT '',
    ADD COLUMN postal_code text NOT NULL DEFAULT '',
    ADD COLUMN street text NOT NULL DEFAULT '',
    ADD COLUMN street_number text NOT NULL DEFAULT '',
    ADD COLUMN complement text NOT NULL DEFAULT '',
    ADD COLUMN district text NOT NULL DEFAULT '',
    ADD COLUMN city text NOT NULL DEFAULT '',
    ADD COLUMN state text NOT NULL DEFAULT '',
    ADD COLUMN latitude double precision,
    ADD COLUMN longitude double precision;

UPDATE service_requests request SET
    client_request_id = gen_random_uuid(),
    quoted_price_cents = service.price_cents,
    scheduled_for = COALESCE(request.scheduled_for, request.created_at + interval '1 hour')
FROM services service
WHERE service.id = request.service_id;

UPDATE service_requests request SET
    address_label = address.label,
    formatted_address = address.formatted_address,
    postal_code = address.postal_code,
    street = address.street,
    street_number = address.street_number,
    complement = address.complement,
    district = address.district,
    city = address.city,
    state = address.state,
    latitude = address.latitude,
    longitude = address.longitude
FROM user_addresses address
WHERE address.firebase_uid = request.customer_uid
  AND address.is_default AND address.active;

ALTER TABLE service_requests
    ALTER COLUMN client_request_id SET NOT NULL,
    ALTER COLUMN quoted_price_cents SET NOT NULL,
    ALTER COLUMN scheduled_for SET NOT NULL,
    ADD CONSTRAINT service_requests_quoted_price_check CHECK (quoted_price_cents >= 0),
    ADD CONSTRAINT service_requests_address_length_check
        CHECK (char_length(address_label) <= 40 AND char_length(formatted_address) <= 240),
    ADD CONSTRAINT service_requests_coordinates_pair_check
        CHECK ((latitude IS NULL) = (longitude IS NULL)),
    ADD CONSTRAINT service_requests_latitude_check CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    ADD CONSTRAINT service_requests_longitude_check CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180);

CREATE UNIQUE INDEX service_requests_customer_client_id_idx
    ON service_requests (customer_uid, client_request_id);
CREATE INDEX service_requests_provider_schedule_idx
    ON service_requests (provider_id, status, scheduled_for, id);

-- +goose Down
DROP INDEX IF EXISTS service_requests_provider_schedule_idx;
DROP INDEX IF EXISTS service_requests_customer_client_id_idx;
ALTER TABLE service_requests
    DROP CONSTRAINT IF EXISTS service_requests_longitude_check,
    DROP CONSTRAINT IF EXISTS service_requests_latitude_check,
    DROP CONSTRAINT IF EXISTS service_requests_coordinates_pair_check,
    DROP CONSTRAINT IF EXISTS service_requests_address_length_check,
    DROP CONSTRAINT IF EXISTS service_requests_quoted_price_check,
    ALTER COLUMN scheduled_for DROP NOT NULL,
    DROP COLUMN IF EXISTS longitude,
    DROP COLUMN IF EXISTS latitude,
    DROP COLUMN IF EXISTS state,
    DROP COLUMN IF EXISTS city,
    DROP COLUMN IF EXISTS district,
    DROP COLUMN IF EXISTS complement,
    DROP COLUMN IF EXISTS street_number,
    DROP COLUMN IF EXISTS street,
    DROP COLUMN IF EXISTS postal_code,
    DROP COLUMN IF EXISTS formatted_address,
    DROP COLUMN IF EXISTS address_label,
    DROP COLUMN IF EXISTS quoted_price_cents,
    DROP COLUMN IF EXISTS client_request_id;
