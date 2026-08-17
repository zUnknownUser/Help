-- +goose Up
CREATE INDEX user_profiles_display_name_cursor_idx
    ON user_profiles (lower(display_name), firebase_uid);

-- +goose Down
DROP INDEX IF EXISTS user_profiles_display_name_cursor_idx;
