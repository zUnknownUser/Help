-- +goose Up
-- Remove only the prototype records shipped by the old development seed.
DELETE FROM promotion_actions WHERE promotion_id IN ('air-conditioning', 'trusted-home', 'schedule');
DELETE FROM promotion_features WHERE promotion_id IN ('air-conditioning', 'trusted-home', 'schedule');
DELETE FROM promotions WHERE id IN ('air-conditioning', 'trusted-home', 'schedule');
DELETE FROM services WHERE id IN ('home-cleaning', 'air-conditioning-repair', 'electrical-maintenance');
DELETE FROM providers WHERE id = 'help-partner' AND owner_uid IS NULL;
DELETE FROM categories WHERE id IN (
    'home-cleaning', 'air-conditioning', 'plumbing', 'electrical',
    'washing-machine', 'refrigerator', 'microwave', 'more'
);
DELETE FROM home_benefits WHERE id IN ('verified', 'pricing', 'warranty', 'tracking');

INSERT INTO home_configuration (
    id, search_placeholder, categories_title, recommendations_title
) VALUES (
    1, 'Busque por um serviço ou profissional', 'Serviços disponíveis',
    'Perto de você'
) ON CONFLICT (id) DO UPDATE SET
    search_placeholder = EXCLUDED.search_placeholder,
    categories_title = EXCLUDED.categories_title,
    recommendations_title = EXCLUDED.recommendations_title,
    updated_at = now();

ALTER TABLE user_addresses
    ADD COLUMN postal_code text NOT NULL DEFAULT '',
    ADD COLUMN street text NOT NULL DEFAULT '',
    ADD COLUMN street_number text NOT NULL DEFAULT '',
    ADD COLUMN complement text NOT NULL DEFAULT '',
    ADD COLUMN district text NOT NULL DEFAULT '',
    ADD COLUMN city text NOT NULL DEFAULT '',
    ADD COLUMN state text NOT NULL DEFAULT '',
    ADD COLUMN latitude double precision,
    ADD COLUMN longitude double precision,
    ADD CONSTRAINT user_addresses_latitude_check
        CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    ADD CONSTRAINT user_addresses_longitude_check
        CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    ADD CONSTRAINT user_addresses_coordinates_pair_check
        CHECK ((latitude IS NULL) = (longitude IS NULL));
CREATE INDEX user_addresses_geo_idx
    ON user_addresses (latitude, longitude)
    WHERE active AND latitude IS NOT NULL;

CREATE TABLE device_installations (
    installation_id uuid PRIMARY KEY,
    firebase_uid text NOT NULL REFERENCES user_profiles (firebase_uid) ON DELETE CASCADE,
    platform text NOT NULL CHECK (platform IN ('android', 'ios')),
    fcm_token text NOT NULL UNIQUE,
    enabled boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_seen_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX device_installations_user_enabled_idx
    ON device_installations (firebase_uid) WHERE enabled;

ALTER TABLE notifications
    ADD COLUMN kind text NOT NULL DEFAULT 'general',
    ADD COLUMN data jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE conversations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    kind text NOT NULL DEFAULT 'direct' CHECK (kind IN ('direct')),
    direct_key text UNIQUE,
    created_by text NOT NULL REFERENCES user_profiles (firebase_uid),
    last_sequence bigint NOT NULL DEFAULT 0 CHECK (last_sequence >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((kind = 'direct') = (direct_key IS NOT NULL))
);

CREATE TABLE conversation_members (
    conversation_id uuid NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
    firebase_uid text NOT NULL REFERENCES user_profiles (firebase_uid) ON DELETE CASCADE,
    last_delivered_sequence bigint NOT NULL DEFAULT 0 CHECK (last_delivered_sequence >= 0),
    last_read_sequence bigint NOT NULL DEFAULT 0 CHECK (last_read_sequence >= 0),
    joined_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (conversation_id, firebase_uid),
    CHECK (last_read_sequence <= last_delivered_sequence)
);
CREATE INDEX conversation_members_user_idx
    ON conversation_members (firebase_uid, conversation_id);

CREATE TABLE chat_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
    sender_uid text NOT NULL REFERENCES user_profiles (firebase_uid),
    client_id uuid NOT NULL,
    sequence bigint NOT NULL CHECK (sequence > 0),
    content text NOT NULL CHECK (char_length(content) BETWEEN 1 AND 4000),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (sender_uid, client_id),
    UNIQUE (conversation_id, sequence)
);
CREATE INDEX chat_messages_conversation_sequence_desc_idx
    ON chat_messages (conversation_id, sequence DESC);

-- +goose Down
DROP TABLE IF EXISTS chat_messages;
DROP TABLE IF EXISTS conversation_members;
DROP TABLE IF EXISTS conversations;
ALTER TABLE notifications DROP COLUMN IF EXISTS data, DROP COLUMN IF EXISTS kind;
DROP TABLE IF EXISTS device_installations;
DROP INDEX IF EXISTS user_addresses_geo_idx;
ALTER TABLE user_addresses
    DROP CONSTRAINT IF EXISTS user_addresses_coordinates_pair_check,
    DROP CONSTRAINT IF EXISTS user_addresses_longitude_check,
    DROP CONSTRAINT IF EXISTS user_addresses_latitude_check,
    DROP COLUMN IF EXISTS longitude,
    DROP COLUMN IF EXISTS latitude,
    DROP COLUMN IF EXISTS state,
    DROP COLUMN IF EXISTS city,
    DROP COLUMN IF EXISTS district,
    DROP COLUMN IF EXISTS complement,
    DROP COLUMN IF EXISTS street_number,
    DROP COLUMN IF EXISTS street,
    DROP COLUMN IF EXISTS postal_code;
