-- +goose Up
CREATE INDEX service_requests_provider_created_idx
    ON service_requests (provider_id, created_at DESC, id DESC);

-- +goose Down
DROP INDEX IF EXISTS service_requests_provider_created_idx;
