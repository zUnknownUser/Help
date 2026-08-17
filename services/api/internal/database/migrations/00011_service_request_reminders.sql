-- +goose Up
CREATE TABLE service_request_reminder_dispatches (
    request_id uuid NOT NULL REFERENCES service_requests (id) ON DELETE CASCADE,
    recipient_uid text NOT NULL REFERENCES user_profiles (firebase_uid) ON DELETE CASCADE,
    reminder_kind text NOT NULL CHECK (reminder_kind IN ('24h', '1h')),
    notification_id uuid REFERENCES notifications (id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (request_id, recipient_uid, reminder_kind)
);
CREATE INDEX service_request_reminders_pending_idx
    ON service_request_reminder_dispatches (created_at)
    WHERE notification_id IS NULL;

-- +goose Down
DROP TABLE IF EXISTS service_request_reminder_dispatches;

