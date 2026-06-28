CREATE TABLE operations (
    id            UUID        PRIMARY KEY,
    type          TEXT        NOT NULL,
    payload       JSONB       NOT NULL DEFAULT '{}',
    status        TEXT        NOT NULL DEFAULT 'optimistic',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at  TIMESTAMPTZ
);
