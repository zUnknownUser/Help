-- +goose Up
CREATE INDEX service_requests_provider_agenda_idx
    ON service_requests (provider_id, scheduled_for, id)
    WHERE status IN ('pending', 'accepted', 'in_progress', 'completed', 'no_show');

CREATE INDEX service_requests_reminder_due_idx
    ON service_requests (scheduled_for, id)
    WHERE status = 'accepted';

-- +goose Down
DROP INDEX IF EXISTS service_requests_reminder_due_idx;
DROP INDEX IF EXISTS service_requests_provider_agenda_idx;
