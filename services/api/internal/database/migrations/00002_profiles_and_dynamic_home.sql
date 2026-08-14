-- +goose Up
ALTER TABLE home_configuration
    ADD COLUMN categories_title text,
    ADD COLUMN recommendations_title text,
    DROP COLUMN address,
    DROP COLUMN availability_label;

ALTER TABLE services
    ADD COLUMN category_id text REFERENCES categories (id);
UPDATE services SET category_id = CASE id
    WHEN 'home-cleaning' THEN 'home-cleaning'
    WHEN 'air-conditioning-repair' THEN 'air-conditioning'
    WHEN 'electrical-maintenance' THEN 'electrical'
END WHERE category_id IS NULL;
CREATE INDEX services_category_id_idx ON services (category_id) WHERE active;

ALTER TABLE promotion_actions
    ADD COLUMN action_type text NOT NULL DEFAULT 'none',
    ADD COLUMN action_target text,
    ADD CONSTRAINT promotion_actions_target_check CHECK (
        (action_type = 'none' AND action_target IS NULL) OR
        (action_type = 'all_services' AND action_target IS NULL) OR
        (action_type = 'category' AND char_length(action_target) > 0)
    );

CREATE TABLE user_profiles (
    firebase_uid text PRIMARY KEY,
    email text NOT NULL,
    display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 2 AND 80),
    active_role text NOT NULL CHECK (active_role IN ('customer', 'provider')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_roles (
    firebase_uid text NOT NULL REFERENCES user_profiles (firebase_uid) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('customer', 'provider')),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (firebase_uid, role)
);

CREATE TABLE user_addresses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid text NOT NULL REFERENCES user_profiles (firebase_uid) ON DELETE CASCADE,
    label text NOT NULL CHECK (char_length(label) BETWEEN 1 AND 40),
    formatted_address text NOT NULL CHECK (char_length(formatted_address) BETWEEN 5 AND 240),
    is_default boolean NOT NULL DEFAULT false,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX user_addresses_one_default_idx
    ON user_addresses (firebase_uid) WHERE is_default AND active;
CREATE INDEX user_addresses_user_idx ON user_addresses (firebase_uid) WHERE active;

CREATE TABLE notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid text NOT NULL REFERENCES user_profiles (firebase_uid) ON DELETE CASCADE,
    title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
    body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
    read_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_user_created_idx
    ON notifications (firebase_uid, created_at DESC);
CREATE INDEX notifications_user_unread_idx
    ON notifications (firebase_uid) WHERE read_at IS NULL;

ALTER TABLE providers
    ADD COLUMN owner_uid text REFERENCES user_profiles (firebase_uid) ON DELETE SET NULL,
    ADD COLUMN onboarding_status text;
UPDATE providers SET onboarding_status = 'approved' WHERE onboarding_status IS NULL;
ALTER TABLE providers
    ALTER COLUMN onboarding_status SET DEFAULT 'pending',
    ALTER COLUMN onboarding_status SET NOT NULL,
    ADD CONSTRAINT providers_onboarding_status_check
        CHECK (onboarding_status IN ('pending', 'approved', 'rejected'));
CREATE UNIQUE INDEX providers_owner_uid_idx ON providers (owner_uid) WHERE owner_uid IS NOT NULL;

-- +goose Down
DROP INDEX IF EXISTS providers_owner_uid_idx;
ALTER TABLE providers
    DROP CONSTRAINT IF EXISTS providers_onboarding_status_check,
    DROP COLUMN IF EXISTS onboarding_status,
    DROP COLUMN IF EXISTS owner_uid;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS notifications;
DROP INDEX IF EXISTS user_addresses_one_default_idx;
DROP INDEX IF EXISTS user_addresses_user_idx;
DROP TABLE IF EXISTS user_addresses;
DROP TABLE IF EXISTS user_profiles;
ALTER TABLE promotion_actions
    DROP CONSTRAINT IF EXISTS promotion_actions_target_check,
    DROP COLUMN IF EXISTS action_target,
    DROP COLUMN IF EXISTS action_type;
DROP INDEX IF EXISTS services_category_id_idx;
ALTER TABLE services DROP COLUMN IF EXISTS category_id;
ALTER TABLE home_configuration
	DROP COLUMN IF EXISTS recommendations_title,
	DROP COLUMN IF EXISTS categories_title,
	ADD COLUMN address text NOT NULL DEFAULT '',
	ADD COLUMN availability_label text NOT NULL DEFAULT '';
