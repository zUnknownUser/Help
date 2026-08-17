-- +goose Up
ALTER TABLE service_request_commands
    ADD COLUMN reason text NOT NULL DEFAULT '' CHECK (char_length(reason) <= 500);

-- +goose Down
ALTER TABLE service_request_commands DROP COLUMN IF EXISTS reason;
