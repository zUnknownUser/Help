-- +goose Up
ALTER TABLE service_requests DROP CONSTRAINT service_requests_status_check;
ALTER TABLE service_requests
    ADD CONSTRAINT service_requests_status_check CHECK (
        status IN ('pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled')
    ),
    ADD COLUMN version integer NOT NULL DEFAULT 0 CHECK (version >= 0),
    ADD COLUMN status_reason text NOT NULL DEFAULT '' CHECK (char_length(status_reason) <= 500),
    ADD COLUMN status_changed_at timestamptz NOT NULL DEFAULT now();

CREATE TABLE service_request_commands (
    actor_uid text NOT NULL REFERENCES user_profiles (firebase_uid) ON DELETE CASCADE,
    client_command_id uuid NOT NULL,
    request_id uuid NOT NULL REFERENCES service_requests (id) ON DELETE CASCADE,
    target_status text NOT NULL,
    resulting_version integer NOT NULL CHECK (resulting_version > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (actor_uid, client_command_id)
);

DROP INDEX IF EXISTS service_requests_customer_created_idx;
DROP INDEX IF EXISTS service_requests_provider_created_idx;
CREATE INDEX service_requests_customer_feed_idx
    ON service_requests (customer_uid, updated_at DESC, id DESC);
CREATE INDEX service_requests_provider_feed_idx
    ON service_requests (provider_id, updated_at DESC, id DESC);

CREATE TABLE notification_push_outbox (
    notification_id uuid PRIMARY KEY REFERENCES notifications (id) ON DELETE CASCADE,
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    available_at timestamptz NOT NULL DEFAULT now(),
    locked_at timestamptz,
    delivered_at timestamptz,
    last_error text NOT NULL DEFAULT '' CHECK (char_length(last_error) <= 500)
);
CREATE INDEX notification_push_outbox_due_idx
    ON notification_push_outbox (available_at, notification_id)
    WHERE delivered_at IS NULL;

-- +goose Down
DROP TABLE IF EXISTS notification_push_outbox;
DROP INDEX IF EXISTS service_requests_provider_feed_idx;
DROP INDEX IF EXISTS service_requests_customer_feed_idx;
CREATE INDEX service_requests_customer_created_idx
    ON service_requests (customer_uid, created_at DESC);
CREATE INDEX service_requests_provider_created_idx
    ON service_requests (provider_id, created_at DESC, id DESC);
DROP TABLE IF EXISTS service_request_commands;
ALTER TABLE service_requests
    DROP COLUMN IF EXISTS status_changed_at,
    DROP COLUMN IF EXISTS status_reason,
    DROP COLUMN IF EXISTS version,
    DROP CONSTRAINT service_requests_status_check,
    ADD CONSTRAINT service_requests_status_check CHECK (
        status IN ('pending', 'accepted', 'rejected', 'completed', 'cancelled')
    );
