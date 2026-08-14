-- +goose Up
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX user_profiles_display_name_trgm_idx
    ON user_profiles USING gin (display_name gin_trgm_ops);
CREATE INDEX services_title_trgm_idx
    ON services USING gin (title gin_trgm_ops) WHERE active;
CREATE INDEX providers_name_trgm_idx
    ON providers USING gin (name gin_trgm_ops) WHERE active;

-- +goose Down
DROP INDEX IF EXISTS providers_name_trgm_idx;
DROP INDEX IF EXISTS services_title_trgm_idx;
DROP INDEX IF EXISTS user_profiles_display_name_trgm_idx;
