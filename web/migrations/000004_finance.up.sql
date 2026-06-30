-- All tables follow BFF convention:
--   customer_id: isolation key for ElectricSQL per-customer shaping
--   expiry: NULL = confirmed by backend event, non-NULL = optimistic write
--   request_id: idempotency key

CREATE TABLE workspaces (
  id            TEXT PRIMARY KEY,
  customer_id   TEXT NOT NULL,
  name          TEXT NOT NULL,
  base_currency TEXT NOT NULL,
  expiry        TIMESTAMPTZ,
  request_id    TEXT
);
CREATE INDEX workspaces_customer_id ON workspaces (customer_id);

-- Per-workspace active currencies. Starts with base_currency on workspace creation.
-- Grows as users add Cash accounts with new currencies.
CREATE TABLE workspace_currencies (
  workspace_id  TEXT NOT NULL,
  customer_id   TEXT NOT NULL,
  currency_code TEXT NOT NULL,
  currency_name TEXT NOT NULL,
  PRIMARY KEY (workspace_id, currency_code)
);
CREATE INDEX workspace_currencies_customer ON workspace_currencies (customer_id);

-- Accounts: Cash (holds money in a currency), External Income/Expense, or FxExchanger (system).
-- account_type is a JSONB discriminated union matching the AccountType TS type.
CREATE TABLE accounts (
  id           TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  customer_id  TEXT NOT NULL,
  name         TEXT NOT NULL,
  icon         TEXT NOT NULL DEFAULT '',
  description  TEXT NOT NULL DEFAULT '',
  category     TEXT NOT NULL DEFAULT '',
  enabled      BOOLEAN NOT NULL DEFAULT TRUE,
  account_type JSONB NOT NULL,
  expiry       TIMESTAMPTZ,
  request_id   TEXT
);
CREATE INDEX accounts_workspace ON accounts (workspace_id);
CREATE INDEX accounts_customer  ON accounts (customer_id);

-- Journal entries: the immutable record of a financial event.
-- line_items is a JSONB discriminated union matching the LineItems TS type.
CREATE TABLE journal_entries (
  id           TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  customer_id  TEXT NOT NULL,
  date         DATE NOT NULL,
  line_items   JSONB NOT NULL,
  expiry       TIMESTAMPTZ,
  request_id   TEXT
);
CREATE INDEX journal_entries_workspace ON journal_entries (workspace_id);
CREATE INDEX journal_entries_customer  ON journal_entries (customer_id);
CREATE INDEX journal_entries_date      ON journal_entries (workspace_id, date DESC);

-- Denormalized per-account, per-currency transaction rows.
-- Computed from journal_entries.line_items on write. Used for transaction lists and balance queries.
CREATE TABLE journal_entry_account_transactions (
  journal_entry_id TEXT NOT NULL,
  workspace_id     TEXT NOT NULL,
  customer_id      TEXT NOT NULL,
  account_id       TEXT NOT NULL,
  currency_code    TEXT NOT NULL,
  increase         NUMERIC(20, 8) NOT NULL DEFAULT 0,
  decrease         NUMERIC(20, 8) NOT NULL DEFAULT 0,
  PRIMARY KEY (journal_entry_id, account_id, currency_code)
);
CREATE INDEX jeat_workspace ON journal_entry_account_transactions (workspace_id);
CREATE INDEX jeat_customer  ON journal_entry_account_transactions (customer_id);
CREATE INDEX jeat_account   ON journal_entry_account_transactions (account_id);

-- Current balance snapshot per workspace.
-- balance_of_accounts: { [account_id]: { [currency_code]: { increase, decrease, balance } } }
-- Updated atomically with each journal entry insert/update.
CREATE TABLE balance_snapshots (
  workspace_id        TEXT PRIMARY KEY,
  customer_id         TEXT NOT NULL,
  balance_of_accounts JSONB NOT NULL DEFAULT '{}'
);
CREATE INDEX balance_snapshots_customer ON balance_snapshots (customer_id);

-- Add all finance tables to the ElectricSQL logical replication publication.
-- The publication is created by Electric on first start; if this migration runs
-- before Electric, the DO block is a no-op and Electric will re-run its setup.
-- If Electric has already created the publication, we add the tables here.
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_publication WHERE pubname = 'electric_publication_default') THEN
    ALTER PUBLICATION electric_publication_default ADD TABLE
      workspaces,
      workspace_currencies,
      accounts,
      journal_entries,
      journal_entry_account_transactions,
      balance_snapshots;
  END IF;
END $$;
