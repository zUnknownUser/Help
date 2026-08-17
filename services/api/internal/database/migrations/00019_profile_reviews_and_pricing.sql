-- +goose Up
ALTER TABLE user_profiles
    ADD COLUMN phone text NOT NULL DEFAULT '' CHECK (char_length(phone) <= 20),
    ADD COLUMN contact_preference text NOT NULL DEFAULT 'chat'
        CHECK (contact_preference IN ('chat', 'phone', 'email')),
    ADD COLUMN photo_visibility text NOT NULL DEFAULT 'everyone'
        CHECK (photo_visibility IN ('everyone', 'conversations', 'nobody')),
    ADD COLUMN last_seen_visibility text NOT NULL DEFAULT 'everyone'
        CHECK (last_seen_visibility IN ('everyone', 'conversations', 'nobody')),
    ADD COLUMN show_online boolean NOT NULL DEFAULT true,
    ADD COLUMN allow_conversation_requests boolean NOT NULL DEFAULT true,
    ADD COLUMN avatar_storage_key text,
    ADD COLUMN avatar_content_type text;

ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_avatar_check CHECK (
    (avatar_storage_key IS NULL AND avatar_content_type IS NULL) OR
    (char_length(avatar_storage_key) > 0 AND avatar_content_type IN ('image/jpeg', 'image/png', 'image/webp'))
);

ALTER TABLE providers
    ADD COLUMN professional_title text NOT NULL DEFAULT '' CHECK (char_length(professional_title) <= 100),
    ADD COLUMN bio text NOT NULL DEFAULT '' CHECK (char_length(bio) <= 1000),
    ADD COLUMN years_experience smallint CHECK (years_experience BETWEEN 0 AND 80),
    ADD COLUMN service_radius_km smallint NOT NULL DEFAULT 10 CHECK (service_radius_km BETWEEN 1 AND 100);

CREATE TABLE provider_portfolio_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id text NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    storage_key text NOT NULL,
    content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp')),
    caption text NOT NULL DEFAULT '' CHECK (char_length(caption) <= 120),
    position smallint NOT NULL DEFAULT 0 CHECK (position >= 0),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX provider_portfolio_items_provider_idx
    ON provider_portfolio_items(provider_id, position, created_at, id);

ALTER TABLE services DROP CONSTRAINT IF EXISTS services_old_price_cents_check;
ALTER TABLE services DROP CONSTRAINT IF EXISTS services_check;
ALTER TABLE services ALTER COLUMN old_price_cents DROP NOT NULL;
UPDATE services SET old_price_cents = NULL WHERE old_price_cents <= price_cents;
ALTER TABLE services ADD CONSTRAINT services_old_price_cents_check CHECK (
    old_price_cents IS NULL OR old_price_cents > price_cents
);

ALTER TABLE help_now_requests ALTER COLUMN category_id DROP NOT NULL;

CREATE TABLE service_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id uuid NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    service_id text NOT NULL REFERENCES services(id),
    reviewer_uid text NOT NULL REFERENCES user_profiles(firebase_uid) ON DELETE CASCADE,
    reviewee_uid text NOT NULL REFERENCES user_profiles(firebase_uid) ON DELETE CASCADE,
    reviewer_role text NOT NULL CHECK (reviewer_role IN ('customer', 'provider')),
    rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment text NOT NULL DEFAULT '' CHECK (char_length(comment) <= 800),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(service_request_id, reviewer_uid),
    CHECK (reviewer_uid <> reviewee_uid)
);
CREATE INDEX service_reviews_reviewee_idx
    ON service_reviews(reviewee_uid, created_at DESC, id DESC);
CREATE INDEX service_reviews_service_idx
    ON service_reviews(service_id, created_at DESC, id DESC)
    WHERE reviewer_role = 'customer';

-- +goose Down
DROP TABLE IF EXISTS service_reviews;
DELETE FROM help_now_requests WHERE category_id IS NULL;
ALTER TABLE help_now_requests ALTER COLUMN category_id SET NOT NULL;
UPDATE services SET old_price_cents = price_cents WHERE old_price_cents IS NULL;
ALTER TABLE services ALTER COLUMN old_price_cents SET NOT NULL;
ALTER TABLE services DROP CONSTRAINT IF EXISTS services_old_price_cents_check;
ALTER TABLE services DROP CONSTRAINT IF EXISTS services_check;
ALTER TABLE services ADD CONSTRAINT services_old_price_cents_check CHECK (old_price_cents >= price_cents);
DROP TABLE IF EXISTS provider_portfolio_items;
ALTER TABLE providers
    DROP COLUMN IF EXISTS service_radius_km,
    DROP COLUMN IF EXISTS years_experience,
    DROP COLUMN IF EXISTS bio,
    DROP COLUMN IF EXISTS professional_title;
ALTER TABLE user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_avatar_check,
    DROP COLUMN IF EXISTS avatar_content_type,
    DROP COLUMN IF EXISTS avatar_storage_key,
    DROP COLUMN IF EXISTS allow_conversation_requests,
    DROP COLUMN IF EXISTS show_online,
    DROP COLUMN IF EXISTS last_seen_visibility,
    DROP COLUMN IF EXISTS photo_visibility,
    DROP COLUMN IF EXISTS contact_preference,
    DROP COLUMN IF EXISTS phone;
