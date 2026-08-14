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

INSERT INTO home_configuration (address, availability_label, search_placeholder)
VALUES ('Av. Eduardo Ribeiro, 520', 'Serviços disponíveis na sua região', 'Busque por um serviço ou profissional');

INSERT INTO home_benefits (id, label, icon_key, position) VALUES
    ('verified', E'Profissionais\nverificados', 'verified', 1),
    ('pricing', E'Preços\ntransparentes', 'pricing', 2),
    ('warranty', E'Garantia de\naté 30 dias', 'warranty', 3),
    ('tracking', E'Acompanhe em\ntempo real', 'location', 4);

INSERT INTO categories (id, name, icon_key, position) VALUES
    ('home-cleaning', E'Limpeza\nresidencial', 'home', 1),
    ('air-conditioning', E'Reparo de\nar-condicionado', 'ac', 2),
    ('plumbing', 'Encanador', 'plumbing', 3),
    ('electrical', 'Eletricista', 'electrical', 4),
    ('washing-machine', E'Máquina de\nlavar', 'laundry', 5),
    ('refrigerator', 'Geladeira', 'refrigerator', 6),
    ('microwave', 'Micro-ondas', 'microwave', 7),
    ('more', E'Mais\nserviços', 'more', 8);

INSERT INTO providers (id, name, verified)
VALUES ('help-partner', 'Parceiro Help', true);

INSERT INTO services (
    id, provider_id, title, rating, reviews, duration_minutes, price_cents,
    old_price_cents, image_alignment, badge, featured_position
) VALUES
    ('home-cleaning', 'help-partner', 'Limpeza residencial', 4.8, 2300, 150, 7900, 9900, 0.18, 'Mais vendido', 1),
    ('air-conditioning-repair', 'help-partner', 'Reparo de ar-condicionado', 4.7, 1800, 60, 5900, 7900, 0.78, '', 2),
    ('electrical-maintenance', 'help-partner', 'Manutenção elétrica', 4.9, 940, 90, 8900, 10900, 0.52, '', 3);

INSERT INTO promotions (id, eyebrow, title, position) VALUES
    ('air-conditioning', 'Seu ar não está gelando?', 'A gente resolve rápido.', 1),
    ('trusted-home', 'Sua casa em boas mãos', 'Profissionais perto de você.', 2),
    ('schedule', 'Precisa para outro dia?', 'Agende no melhor horário.', 3);

INSERT INTO promotion_features (promotion_id, position, icon_key, label) VALUES
    ('air-conditioning', 1, 'fast', 'Atendimento a partir de 30 min'),
    ('air-conditioning', 2, 'verified', 'Profissionais verificados'),
    ('trusted-home', 1, 'verified', 'Parceiros avaliados pela comunidade'),
    ('schedule', 1, 'calendar', 'Escolha o dia e horário');

INSERT INTO promotion_actions (id, promotion_id, position, label, icon_key, style) VALUES
    ('fast-service', 'air-conditioning', 1, 'Serviço rápido', 'fast', 'primary'),
    ('schedule', 'air-conditioning', 2, 'Agendar', 'calendar', 'secondary'),
    ('explore', 'trusted-home', 1, 'Explorar serviços', 'search', 'primary'),
    ('schedule', 'schedule', 1, 'Agendar', 'calendar', 'primary');

-- +goose Down
DROP TABLE IF EXISTS promotion_actions;
DROP TABLE IF EXISTS promotion_features;
DROP TABLE IF EXISTS promotions;
DROP TABLE IF EXISTS services;
DROP TABLE IF EXISTS providers;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS home_benefits;
DROP TABLE IF EXISTS home_configuration;
