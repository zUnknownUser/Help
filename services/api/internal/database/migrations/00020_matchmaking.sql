-- +goose Up
CREATE TABLE matchmaking_runs (
    id uuid PRIMARY KEY,
    viewer_uid text NOT NULL REFERENCES user_profiles(firebase_uid) ON DELETE CASCADE,
    latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    radius_km real NOT NULL CHECK (radius_km > 0 AND radius_km <= 100),
    algorithm_version text NOT NULL CHECK (char_length(algorithm_version) BETWEEN 1 AND 40),
    result_count smallint NOT NULL CHECK (result_count BETWEEN 0 AND 30),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX matchmaking_runs_viewer_created_idx
    ON matchmaking_runs(viewer_uid, created_at DESC, id DESC);

CREATE TABLE matchmaking_results (
    run_id uuid NOT NULL REFERENCES matchmaking_runs(id) ON DELETE CASCADE,
    service_id text NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    provider_id text NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    position smallint NOT NULL CHECK (position BETWEEN 1 AND 30),
    score real NOT NULL CHECK (score BETWEEN 0 AND 1),
    reason_codes text[] NOT NULL DEFAULT '{}',
    PRIMARY KEY (run_id, service_id),
    UNIQUE (run_id, position)
);
CREATE INDEX matchmaking_results_service_idx
    ON matchmaking_results(service_id, run_id);

-- +goose Down
DROP TABLE IF EXISTS matchmaking_results;
DROP TABLE IF EXISTS matchmaking_runs;
