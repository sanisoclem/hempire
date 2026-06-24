CREATE TABLE customers (
  customer_id  TEXT PRIMARY KEY,
  created_on   TIMESTAMPTZ NOT NULL,
  updated_on   TIMESTAMPTZ NOT NULL,
  active       BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE identity_providers (
  identity_provider_id  TEXT PRIMARY KEY,
  enable_customers      BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE identities (
  identity_provider_id  TEXT NOT NULL REFERENCES identity_providers,
  identity_id           TEXT NOT NULL,
  customer_id           TEXT NOT NULL REFERENCES customers,
  active                BOOLEAN NOT NULL DEFAULT true,
  PRIMARY KEY (identity_provider_id, identity_id)
);

CREATE TABLE invites (
  invite_id   TEXT PRIMARY KEY,
  source      TEXT NOT NULL,
  created_on  TIMESTAMPTZ NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT true,
  customer_id TEXT REFERENCES customers,
  comment     TEXT
);
