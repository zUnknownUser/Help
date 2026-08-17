-- +goose Up
ALTER TABLE user_profiles
    ADD COLUMN last_seen_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE chat_messages
    ADD COLUMN edited_at timestamptz,
    ADD COLUMN deleted_at timestamptz,
    ADD COLUMN version integer NOT NULL DEFAULT 1 CHECK (version > 0);

ALTER TABLE chat_messages DROP CONSTRAINT chat_messages_content_check;
ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_content_check CHECK (
    (deleted_at IS NULL AND char_length(content) BETWEEN 1 AND 4000)
    OR (deleted_at IS NOT NULL AND content = '')
);

CREATE TABLE chat_message_mutations (
    operation_id uuid PRIMARY KEY,
    message_id uuid NOT NULL REFERENCES chat_messages (id) ON DELETE CASCADE,
    actor_uid text NOT NULL REFERENCES user_profiles (firebase_uid) ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('edit', 'delete')),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX chat_message_mutations_message_idx
    ON chat_message_mutations (message_id, created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS chat_message_mutations;
ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS chat_messages_content_check;
UPDATE chat_messages SET content = 'Mensagem apagada' WHERE deleted_at IS NOT NULL;
ALTER TABLE chat_messages
    ADD CONSTRAINT chat_messages_content_check
    CHECK (char_length(content) BETWEEN 1 AND 4000);
ALTER TABLE chat_messages
    DROP COLUMN IF EXISTS version,
    DROP COLUMN IF EXISTS deleted_at,
    DROP COLUMN IF EXISTS edited_at;
ALTER TABLE user_profiles DROP COLUMN IF EXISTS last_seen_at;
