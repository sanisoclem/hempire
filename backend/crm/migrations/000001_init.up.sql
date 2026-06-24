CREATE TABLE customers (
  customer_id TEXT PRIMARY KEY,
  created_on  TIMESTAMPTZ NOT NULL,
  updated_on  TIMESTAMPTZ NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE identity_providers (
  identity_provider_id TEXT PRIMARY KEY,
  idp_type             TEXT NOT NULL,
  enable_customers     BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE invites (
  invite_id   TEXT PRIMARY KEY,
  source      TEXT NOT NULL,
  created_on  TIMESTAMPTZ NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT true,
  customer_id TEXT REFERENCES customers,
  comment     TEXT
);
