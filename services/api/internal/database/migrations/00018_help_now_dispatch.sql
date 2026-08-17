-- +goose Up
CREATE TABLE help_now_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_request_id uuid NOT NULL,
    customer_uid text NOT NULL REFERENCES user_profiles(firebase_uid) ON DELETE CASCADE,
    category_id text NOT NULL REFERENCES categories(id),
    note text NOT NULL DEFAULT '' CHECK (char_length(note) <= 500),
    address_label text NOT NULL DEFAULT '' CHECK (char_length(address_label) <= 40),
    formatted_address text NOT NULL CHECK (char_length(formatted_address) BETWEEN 5 AND 240),
    latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    status text NOT NULL DEFAULT 'searching'
        CHECK (status IN ('searching', 'assigned', 'no_provider', 'cancelled')),
    search_wave smallint NOT NULL DEFAULT 0 CHECK (search_wave BETWEEN 0 AND 3),
    next_dispatch_at timestamptz NOT NULL DEFAULT now(),
    search_expires_at timestamptz NOT NULL DEFAULT now() + interval '3 minutes',
    assigned_provider_id text REFERENCES providers(id),
    service_request_id uuid UNIQUE REFERENCES service_requests(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(customer_uid, client_request_id),
    CHECK ((status = 'assigned') = (assigned_provider_id IS NOT NULL AND service_request_id IS NOT NULL))
);
CREATE UNIQUE INDEX help_now_one_active_customer_idx
    ON help_now_requests(customer_uid) WHERE status = 'searching';
CREATE INDEX help_now_dispatch_due_idx
    ON help_now_requests(next_dispatch_at, id) WHERE status = 'searching';
CREATE INDEX help_now_customer_feed_idx
    ON help_now_requests(customer_uid, updated_at DESC, id DESC);

CREATE TABLE provider_help_now_availability (
    provider_id text PRIMARY KEY REFERENCES providers(id) ON DELETE CASCADE,
    enabled boolean NOT NULL DEFAULT false,
    latitude double precision,
    longitude double precision,
    max_distance_km smallint NOT NULL DEFAULT 10 CHECK (max_distance_km BETWEEN 2 AND 50),
    heartbeat_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CHECK (NOT enabled OR (latitude IS NOT NULL AND heartbeat_at IS NOT NULL))
);
CREATE INDEX provider_help_now_available_idx
    ON provider_help_now_availability(heartbeat_at DESC, provider_id) WHERE enabled;

CREATE TABLE help_now_offers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES help_now_requests(id) ON DELETE CASCADE,
    provider_id text NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    wave smallint NOT NULL CHECK (wave BETWEEN 1 AND 3),
    distance_meters integer NOT NULL CHECK (distance_meters >= 0),
    status text NOT NULL DEFAULT 'offered'
        CHECK (status IN ('offered', 'accepted', 'declined', 'expired', 'lost')),
    offered_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    responded_at timestamptz,
    UNIQUE(request_id, provider_id)
);
CREATE INDEX help_now_provider_active_offers_idx
    ON help_now_offers(provider_id, expires_at, offered_at DESC)
    WHERE status = 'offered';

CREATE TABLE help_now_offer_commands (
    actor_uid text NOT NULL REFERENCES user_profiles(firebase_uid) ON DELETE CASCADE,
    client_command_id uuid NOT NULL,
    offer_id uuid NOT NULL REFERENCES help_now_offers(id) ON DELETE CASCADE,
    action text NOT NULL CHECK (action IN ('accept', 'decline')),
    request_id uuid NOT NULL REFERENCES help_now_requests(id) ON DELETE CASCADE,
    service_request_id uuid REFERENCES service_requests(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(actor_uid, client_command_id)
);

-- +goose Down
DROP TABLE IF EXISTS help_now_offer_commands;
DROP TABLE IF EXISTS help_now_offers;
DROP TABLE IF EXISTS provider_help_now_availability;
DROP TABLE IF EXISTS help_now_requests;
