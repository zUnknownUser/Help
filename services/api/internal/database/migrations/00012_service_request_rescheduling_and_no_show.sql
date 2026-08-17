-- +goose Up
ALTER TABLE service_requests DROP CONSTRAINT service_requests_status_check;
ALTER TABLE service_requests ADD CONSTRAINT service_requests_status_check CHECK (
    status IN ('pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled', 'no_show')
);

CREATE TABLE service_request_reschedule_commands (
    actor_uid text NOT NULL REFERENCES user_profiles (firebase_uid) ON DELETE CASCADE,
    client_command_id uuid NOT NULL,
    request_id uuid NOT NULL REFERENCES service_requests (id) ON DELETE CASCADE,
    scheduled_for timestamptz NOT NULL,
    resulting_version integer NOT NULL CHECK (resulting_version > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (actor_uid, client_command_id)
);

-- +goose Down
DROP TABLE IF EXISTS service_request_reschedule_commands;
ALTER TABLE service_requests DROP CONSTRAINT service_requests_status_check;
ALTER TABLE service_requests ADD CONSTRAINT service_requests_status_check CHECK (
    status IN ('pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled')
);
