-- +goose Up
CREATE TABLE service_request_attachments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    uploader_uid text NOT NULL REFERENCES user_profiles(firebase_uid) ON DELETE CASCADE,
    storage_key text NOT NULL UNIQUE,
    content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp')),
    byte_size integer NOT NULL CHECK (byte_size BETWEEN 1 AND 8388608),
    caption text NOT NULL DEFAULT '' CHECK (char_length(caption) <= 160),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX service_request_attachments_request_idx
    ON service_request_attachments(request_id, created_at, id);

CREATE TABLE service_request_quotes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    client_command_id uuid NOT NULL,
    author_uid text NOT NULL REFERENCES user_profiles(firebase_uid) ON DELETE CASCADE,
    author_role text NOT NULL CHECK (author_role IN ('customer', 'provider')),
    revision integer NOT NULL CHECK (revision > 0),
    status text NOT NULL DEFAULT 'proposed'
        CHECK (status IN ('proposed', 'accepted', 'superseded', 'withdrawn')),
    currency char(3) NOT NULL DEFAULT 'BRL' CHECK (currency = 'BRL'),
    total_cents integer NOT NULL CHECK (total_cents BETWEEN 1 AND 100000000),
    message text NOT NULL DEFAULT '' CHECK (char_length(message) <= 1000),
    intent_hash char(64) NOT NULL,
    expires_at timestamptz,
    accepted_at timestamptz,
    accepted_by text REFERENCES user_profiles(firebase_uid),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(request_id, revision),
    UNIQUE(author_uid, client_command_id),
    CHECK (expires_at IS NULL OR expires_at > created_at),
    CHECK (
        (status = 'accepted' AND accepted_at IS NOT NULL AND accepted_by IS NOT NULL)
        OR
        (status <> 'accepted' AND accepted_at IS NULL AND accepted_by IS NULL)
    )
);
CREATE UNIQUE INDEX service_request_quotes_one_proposed_idx
    ON service_request_quotes(request_id) WHERE status = 'proposed';
CREATE INDEX service_request_quotes_request_history_idx
    ON service_request_quotes(request_id, revision DESC);

CREATE TABLE service_request_quote_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_id uuid NOT NULL REFERENCES service_request_quotes(id) ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('labor', 'material', 'addon', 'discount')),
    description text NOT NULL CHECK (char_length(description) BETWEEN 2 AND 120),
    amount_cents integer NOT NULL CHECK (amount_cents BETWEEN 1 AND 100000000),
    position smallint NOT NULL CHECK (position BETWEEN 0 AND 19),
    UNIQUE(quote_id, position)
);
CREATE INDEX service_request_quote_items_quote_idx
    ON service_request_quote_items(quote_id, position);

CREATE TABLE service_request_quote_accept_commands (
    actor_uid text NOT NULL REFERENCES user_profiles(firebase_uid) ON DELETE CASCADE,
    client_command_id uuid NOT NULL,
    request_id uuid NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    quote_id uuid NOT NULL REFERENCES service_request_quotes(id) ON DELETE CASCADE,
    resulting_version integer NOT NULL CHECK (resulting_version > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(actor_uid, client_command_id)
);

-- +goose Down
DROP TABLE IF EXISTS service_request_quote_accept_commands;
DROP TABLE IF EXISTS service_request_quote_items;
DROP INDEX IF EXISTS service_request_quotes_request_history_idx;
DROP INDEX IF EXISTS service_request_quotes_one_proposed_idx;
DROP TABLE IF EXISTS service_request_quotes;
DROP INDEX IF EXISTS service_request_attachments_request_idx;
DROP TABLE IF EXISTS service_request_attachments;
