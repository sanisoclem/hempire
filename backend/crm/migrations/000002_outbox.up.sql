CREATE TABLE outbox (
  id         BIGSERIAL PRIMARY KEY,
  topic      TEXT NOT NULL,
  payload    JSONB NOT NULL,
  created_on TIMESTAMPTZ NOT NULL DEFAULT now()
);
