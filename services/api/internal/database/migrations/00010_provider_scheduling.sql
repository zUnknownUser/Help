-- +goose Up
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE provider_schedule_settings (
    provider_id text PRIMARY KEY REFERENCES providers (id) ON DELETE CASCADE,
    time_zone text NOT NULL DEFAULT 'America/Manaus' CHECK (char_length(time_zone) BETWEEN 1 AND 64),
    minimum_notice_minutes integer NOT NULL DEFAULT 60 CHECK (minimum_notice_minutes BETWEEN 15 AND 10080),
    booking_horizon_days integer NOT NULL DEFAULT 60 CHECK (booking_horizon_days BETWEEN 1 AND 180),
    buffer_minutes integer NOT NULL DEFAULT 15 CHECK (buffer_minutes BETWEEN 0 AND 240),
    slot_interval_minutes integer NOT NULL DEFAULT 30 CHECK (slot_interval_minutes IN (15, 30, 60)),
    version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE provider_availability_rules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id text NOT NULL REFERENCES provider_schedule_settings (provider_id) ON DELETE CASCADE,
    weekday smallint NOT NULL CHECK (weekday BETWEEN 0 AND 6),
    start_minute smallint NOT NULL CHECK (start_minute BETWEEN 0 AND 1425 AND start_minute % 15 = 0),
    end_minute smallint NOT NULL CHECK (end_minute BETWEEN 15 AND 1440 AND end_minute % 15 = 0),
    CHECK (end_minute > start_minute),
    UNIQUE (provider_id, weekday, start_minute, end_minute)
);
CREATE INDEX provider_availability_rules_lookup_idx
    ON provider_availability_rules (provider_id, weekday, start_minute);

CREATE TABLE provider_schedule_blocks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id text NOT NULL REFERENCES provider_schedule_settings (provider_id) ON DELETE CASCADE,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    reason text NOT NULL DEFAULT '' CHECK (char_length(reason) <= 120),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_at > starts_at),
    CHECK (ends_at <= starts_at + interval '31 days')
);
CREATE INDEX provider_schedule_blocks_range_idx
    ON provider_schedule_blocks USING gist (provider_id, tstzrange(starts_at, ends_at, '[)'));

ALTER TABLE service_requests
    ADD COLUMN scheduled_end_at timestamptz,
    ADD COLUMN reservation_end_at timestamptz;

UPDATE service_requests request SET
    scheduled_end_at = request.scheduled_for + make_interval(mins => service.duration_minutes),
    reservation_end_at = request.scheduled_for + make_interval(mins => service.duration_minutes)
FROM services service
WHERE service.id = request.service_id;

ALTER TABLE service_requests
    ALTER COLUMN scheduled_end_at SET NOT NULL,
    ALTER COLUMN reservation_end_at SET NOT NULL,
    ADD CONSTRAINT service_requests_schedule_range_check
        CHECK (scheduled_end_at > scheduled_for AND reservation_end_at >= scheduled_end_at),
    ADD CONSTRAINT service_requests_no_provider_overlap
        EXCLUDE USING gist (
            provider_id WITH =,
            tstzrange(scheduled_for, reservation_end_at, '[)') WITH &&
        ) WHERE (status IN ('pending', 'accepted', 'in_progress'));

INSERT INTO provider_schedule_settings (provider_id)
SELECT id FROM providers
ON CONFLICT DO NOTHING;

INSERT INTO provider_availability_rules (provider_id, weekday, start_minute, end_minute)
SELECT setting.provider_id, weekday, 480, 1080
FROM provider_schedule_settings setting
CROSS JOIN generate_series(1, 6) AS weekday
ON CONFLICT DO NOTHING;

-- +goose Down
ALTER TABLE service_requests
    DROP CONSTRAINT IF EXISTS service_requests_no_provider_overlap,
    DROP CONSTRAINT IF EXISTS service_requests_schedule_range_check,
    DROP COLUMN IF EXISTS reservation_end_at,
    DROP COLUMN IF EXISTS scheduled_end_at;
DROP TABLE IF EXISTS provider_schedule_blocks;
DROP TABLE IF EXISTS provider_availability_rules;
DROP TABLE IF EXISTS provider_schedule_settings;

