DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_publication WHERE pubname = 'electric_publication_default') THEN
    ALTER PUBLICATION electric_publication_default DROP TABLE
      balance_snapshots,
      journal_entry_account_transactions,
      journal_entries,
      accounts,
      workspace_currencies,
      workspaces;
  END IF;
END $$;

DROP TABLE IF EXISTS balance_snapshots;
DROP TABLE IF EXISTS journal_entry_account_transactions;
DROP TABLE IF EXISTS journal_entries;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS workspace_currencies;
DROP TABLE IF EXISTS workspaces;
