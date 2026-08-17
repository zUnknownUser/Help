-- +goose Up
ALTER TABLE conversations
    ADD COLUMN status text NOT NULL DEFAULT 'accepted'
        CHECK (status IN ('pending', 'accepted', 'declined')),
    ADD COLUMN requested_by text REFERENCES user_profiles (firebase_uid),
    ADD COLUMN responded_at timestamptz;

UPDATE conversations SET requested_by = created_by WHERE requested_by IS NULL;
ALTER TABLE conversations ALTER COLUMN requested_by SET NOT NULL;

-- +goose Down
ALTER TABLE conversations
    DROP COLUMN IF EXISTS responded_at,
    DROP COLUMN IF EXISTS requested_by,
    DROP COLUMN IF EXISTS status;
