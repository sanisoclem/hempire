CREATE TABLE users (
  customer_id   TEXT PRIMARY KEY REFERENCES customers (customer_id),
  friendly_name TEXT NOT NULL,
  identity_id   TEXT NOT NULL,
  created_on    TIMESTAMPTZ NOT NULL DEFAULT now()
);
