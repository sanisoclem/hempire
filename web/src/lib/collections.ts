import { browser } from "$app/environment";
import { electricCollectionOptions } from "@tanstack/electric-db-collection";
import { localOnlyCollectionOptions } from "@tanstack/db";
import { createCollection } from "@tanstack/svelte-db";

// ── Row type definitions ───────────────────────────────────────────────────
// These mirror the DB columns exactly. Domain mapping happens in the server layer.
// JSONB columns come through as `unknown` from Electric and are parsed with Zod in components.

export interface UserRow {
	[key: string]: unknown;
	customer_id: string;
	friendly_name: string;
	identity_id: string;
	expiry: string | null;
	request_id: string | null;
}

export interface WorkspaceRow {
	[key: string]: unknown;
	id: string;
	customer_id: string;
	name: string;
	base_currency: string;
	expiry: string | null;
	request_id: string | null;
}

export interface WorkspaceCurrencyRow {
	[key: string]: unknown;
	workspace_id: string;
	customer_id: string;
	currency_code: string;
	currency_name: string;
}

export interface AccountRow {
	[key: string]: unknown;
	id: string;
	workspace_id: string;
	customer_id: string;
	name: string;
	icon: string;
	description: string;
	category: string;
	enabled: boolean;
	account_type: unknown; // JSONB — parse with AccountTypeRowSchema
	expiry: string | null;
	request_id: string | null;
}

export interface JournalEntryRow {
	[key: string]: unknown;
	id: string;
	workspace_id: string;
	customer_id: string;
	date: string; // ISO date string
	line_items: unknown; // JSONB — parse with LineItemsRowSchema
	expiry: string | null;
	request_id: string | null;
}

export interface JournalEntryAccountTransactionRow {
	[key: string]: unknown;
	journal_entry_id: string;
	workspace_id: string;
	customer_id: string;
	account_id: string;
	currency_code: string;
	increase: string;
	decrease: string;
}

export interface BalanceSnapshotRow {
	[key: string]: unknown;
	workspace_id: string;
	customer_id: string;
	balance_of_accounts: unknown; // JSONB — parse with BalanceMapSchema
}

// ── Collection factory ─────────────────────────────────────────────────────

function makeCollection<T extends Record<string, unknown>>(
	id: string,
	getKey: (row: T) => string,
) {
	return browser
		? createCollection(
				electricCollectionOptions<T>({
					id,
					shapeOptions: { url: `${location.origin}/api/shapes/${id}` },
					getKey,
				}),
			)
		: createCollection(localOnlyCollectionOptions<T>({ id, getKey }));
}

// ── Collections ───────────────────────────────────────────────────────────

export const usersCollection = makeCollection<UserRow>("users", (r) => r.customer_id);

export const workspacesCollection = makeCollection<WorkspaceRow>("workspaces", (r) => r.id);

export const workspaceCurrenciesCollection = makeCollection<WorkspaceCurrencyRow>(
	"workspace_currencies",
	(r) => `${r.workspace_id}:${r.currency_code}`,
);

export const accountsCollection = makeCollection<AccountRow>("accounts", (r) => r.id);

export const journalEntriesCollection = makeCollection<JournalEntryRow>(
	"journal_entries",
	(r) => r.id,
);

export const journalEntryTxsCollection =
	makeCollection<JournalEntryAccountTransactionRow>(
		"journal_entry_account_transactions",
		(r) => `${r.journal_entry_id}:${r.account_id}:${r.currency_code}`,
	);

export const balanceSnapshotsCollection = makeCollection<BalanceSnapshotRow>(
	"balance_snapshots",
	(r) => r.workspace_id,
);
