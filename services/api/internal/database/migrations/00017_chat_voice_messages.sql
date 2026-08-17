-- +goose Up
CREATE TABLE chat_media_assets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    owner_uid text NOT NULL REFERENCES user_profiles(firebase_uid) ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('voice')),
    storage_key text NOT NULL UNIQUE,
    content_type text NOT NULL CHECK (content_type IN (
        'audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/ogg', 'audio/webm'
    )),
    byte_size bigint NOT NULL CHECK (byte_size BETWEEN 1 AND 10485760),
    duration_ms integer NOT NULL CHECK (duration_ms BETWEEN 250 AND 300000),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX chat_media_assets_conversation_created_idx
    ON chat_media_assets(conversation_id, created_at DESC);

ALTER TABLE chat_messages
    ADD COLUMN kind text NOT NULL DEFAULT 'text' CHECK (kind IN ('text', 'voice')),
    ADD COLUMN media_id uuid UNIQUE REFERENCES chat_media_assets(id);

ALTER TABLE chat_messages DROP CONSTRAINT chat_messages_content_check;
ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_content_check CHECK (
    deleted_at IS NOT NULL AND content = ''
    OR deleted_at IS NULL AND kind = 'text'
       AND char_length(content) BETWEEN 1 AND 4000 AND media_id IS NULL
    OR deleted_at IS NULL AND kind = 'voice'
       AND content = '' AND media_id IS NOT NULL
);

-- +goose Down
ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS chat_messages_content_check;
DELETE FROM chat_messages WHERE kind = 'voice';
ALTER TABLE chat_messages DROP COLUMN IF EXISTS media_id, DROP COLUMN IF EXISTS kind;
ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_content_check CHECK (
    (deleted_at IS NULL AND char_length(content) BETWEEN 1 AND 4000)
    OR (deleted_at IS NOT NULL AND content = '')
);
DROP TABLE IF EXISTS chat_media_assets;
