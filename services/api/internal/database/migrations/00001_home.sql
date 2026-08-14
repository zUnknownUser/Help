-- +goose Up
CREATE TABLE home_configuration (
    id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    address text NOT NULL,
    availability_label text NOT NULL,
    search_placeholder text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE home_benefits (
    id text PRIMARY KEY,
    label text NOT NULL,
    icon_key text NOT NULL,
    position smallint NOT NULL CHECK (position >= 0),
    active boolean NOT NULL DEFAULT true
);
CREATE INDEX home_benefits_active_position_idx ON home_benefits (position) WHERE active;

CREATE TABLE categories (
    id text PRIMARY KEY,
    name text NOT NULL,
    icon_key text NOT NULL,
    position smallint NOT NULL CHECK (position >= 0),
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX categories_active_position_idx ON categories (position) WHERE active;

CREATE TABLE providers (
    id text PRIMARY KEY,
    name text NOT NULL,
    verified boolean NOT NULL DEFAULT false,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE services (
    id text PRIMARY KEY,
    provider_id text NOT NULL REFERENCES providers (id),
    title text NOT NULL,
    rating numeric(2,1) NOT NULL CHECK (rating BETWEEN 0 AND 5),
    reviews integer NOT NULL DEFAULT 0 CHECK (reviews >= 0),
    duration_minutes integer NOT NULL CHECK (duration_minutes > 0),
    price_cents integer NOT NULL CHECK (price_cents >= 0),
    old_price_cents integer NOT NULL CHECK (old_price_cents >= price_cents),
    image_url text NOT NULL DEFAULT '',
    image_alignment real NOT NULL DEFAULT 0 CHECK (image_alignment BETWEEN -1 AND 1),
    badge text NOT NULL DEFAULT '',
    featured_position smallint CHECK (featured_position >= 0),
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX services_featured_position_idx ON services (featured_position) WHERE active AND featured_position IS NOT NULL;
CREATE INDEX services_provider_id_idx ON services (provider_id) WHERE active;

CREATE TABLE promotions (
    id text PRIMARY KEY,
    eyebrow text NOT NULL,
    title text NOT NULL,
    image_url text NOT NULL DEFAULT '',
    position smallint NOT NULL CHECK (position >= 0),
    active boolean NOT NULL DEFAULT true,
    starts_at timestamptz,
    ends_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);
CREATE INDEX promotions_active_schedule_position_idx ON promotions (position, starts_at, ends_at) WHERE active;

CREATE TABLE promotion_features (
    promotion_id text NOT NULL REFERENCES promotions (id) ON DELETE CASCADE,
    position smallint NOT NULL CHECK (position >= 0),
    icon_key text NOT NULL,
    label text NOT NULL,
    PRIMARY KEY (promotion_id, position)
);

CREATE TABLE promotion_actions (
    id text NOT NULL,
    promotion_id text NOT NULL REFERENCES promotions (id) ON DELETE CASCADE,
    position smallint NOT NULL CHECK (position >= 0),
    label text NOT NULL,
    icon_key text NOT NULL,
    style text NOT NULL CHECK (style IN ('primary', 'secondary')),
    PRIMARY KEY (promotion_id, id),
    UNIQUE (promotion_id, position)
);

-- +goose Down
DROP TABLE IF EXISTS promotion_actions;
DROP TABLE IF EXISTS promotion_features;
DROP TABLE IF EXISTS promotions;
DROP TABLE IF EXISTS services;
DROP TABLE IF EXISTS providers;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS home_benefits;
DROP TABLE IF EXISTS home_configuration;
