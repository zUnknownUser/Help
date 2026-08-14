-- +goose Up
ALTER TABLE providers
    ADD COLUMN accepting_requests boolean NOT NULL DEFAULT true;

ALTER TABLE services
    ADD COLUMN description text NOT NULL DEFAULT '',
    ADD COLUMN published_at timestamptz,
    ADD COLUMN deleted_at timestamptz,
    ADD CONSTRAINT services_title_length_check
        CHECK (char_length(title) BETWEEN 3 AND 100),
    ADD CONSTRAINT services_description_length_check
        CHECK (char_length(description) <= 1000),
    ADD CONSTRAINT services_duration_upper_check
        CHECK (duration_minutes <= 1440),
    ADD CONSTRAINT services_image_url_length_check
        CHECK (char_length(image_url) <= 2048);

UPDATE services SET published_at = created_at WHERE active;

DROP INDEX IF EXISTS services_provider_id_idx;
CREATE INDEX services_provider_id_idx
    ON services (provider_id) WHERE active AND deleted_at IS NULL;
CREATE INDEX services_provider_management_idx
    ON services (provider_id, updated_at DESC, id) WHERE deleted_at IS NULL;

CREATE TABLE service_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id text NOT NULL REFERENCES services (id),
    provider_id text NOT NULL REFERENCES providers (id),
    customer_uid text NOT NULL REFERENCES user_profiles (firebase_uid),
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected', 'completed', 'cancelled')),
    note text NOT NULL DEFAULT '' CHECK (char_length(note) <= 1000),
    scheduled_for timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX service_requests_provider_status_created_idx
    ON service_requests (provider_id, status, created_at DESC);
CREATE INDEX service_requests_customer_created_idx
    ON service_requests (customer_uid, created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS service_requests;
DROP INDEX IF EXISTS services_provider_management_idx;
DROP INDEX IF EXISTS services_provider_id_idx;
CREATE INDEX services_provider_id_idx ON services (provider_id) WHERE active;
ALTER TABLE services
    DROP CONSTRAINT IF EXISTS services_image_url_length_check,
    DROP CONSTRAINT IF EXISTS services_duration_upper_check,
    DROP CONSTRAINT IF EXISTS services_description_length_check,
    DROP CONSTRAINT IF EXISTS services_title_length_check,
    DROP COLUMN IF EXISTS deleted_at,
    DROP COLUMN IF EXISTS published_at,
    DROP COLUMN IF EXISTS description;
ALTER TABLE providers DROP COLUMN IF EXISTS accepting_requests;
