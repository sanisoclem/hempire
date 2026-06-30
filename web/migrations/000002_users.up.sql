-- All BFF tables must include customer_id (partition/isolation key) and expiry.
-- expiry = null means the row is confirmed by a backend event; non-null means optimistic.
-- request_id is the idempotency key for the last write that touched this row.
CREATE TABLE users (
  customer_id   TEXT PRIMARY KEY,
  friendly_name TEXT NOT NULL,
  identity_id   TEXT NOT NULL,
  expiry        TIMESTAMPTZ,
  request_id    TEXT
);
