// Financial data operations for the BFF.
// All writes are optimistic (expiry is set); the backend will confirm by setting expiry=null.
// Each function returns a tagged result — no throws for business logic.

import { trace } from "@opentelemetry/api";
import sql, { withDbSpan } from "$lib/server/db";
import { config } from "$lib/server/config";
import {
	generateWorkspaceId,
	generateAccountId,
	generateEntryId,
	computeAccountTransactions,
	applyTransactionsToBalance,
	type Workspace,
	type WorkspaceCurrency,
	type Account,
	type JournalEntry,
	type AccountType,
	type LineItems,
	type BalanceMap,
	makeWorkspaceId,
	makeAccountId,
	makeEntryId,
} from "$lib/domain";
import { AccountTypeRowSchema, LineItemsRowSchema, BalanceMapSchema } from "$lib/schemas";
import { getCurrencyName } from "$lib/currencies";

const tracer = trace.getTracer("hempire-bff");

type Ok<T> = { readonly success: true; readonly value: T };
type Err = { readonly success: false; readonly error: string };
type Result<T> = Ok<T> | Err;

function ok<T>(value: T): Ok<T> {
	return { success: true, value };
}
function err(error: string): Err {
	return { success: false, error };
}

function optimisticExpiry(): Date {
	const d = new Date();
	d.setMinutes(d.getMinutes() + config.user.expiryMinutes);
	return d;
}

// ── Row shapes from the database ──────────────────────────────────────────

type WorkspaceRow = {
	id: string;
	customer_id: string;
	name: string;
	base_currency: string;
	expiry: Date | null;
	request_id: string | null;
};

type WorkspaceCurrencyRow = {
	workspace_id: string;
	customer_id: string;
	currency_code: string;
	currency_name: string;
};

type AccountRow = {
	id: string;
	workspace_id: string;
	customer_id: string;
	name: string;
	icon: string;
	description: string;
	category: string;
	enabled: boolean;
	account_type: unknown; // JSONB
	expiry: Date | null;
	request_id: string | null;
};

type JournalEntryRow = {
	id: string;
	workspace_id: string;
	customer_id: string;
	date: string;
	line_items: unknown; // JSONB
	expiry: Date | null;
	request_id: string | null;
};

type BalanceSnapshotRow = {
	workspace_id: string;
	customer_id: string;
	balance_of_accounts: unknown; // JSONB
};

// ── Row → domain type mappers ─────────────────────────────────────────────

function rowToWorkspace(row: WorkspaceRow): Result<Workspace> {
	return ok({
		id: makeWorkspaceId(row.id),
		customerId: row.customer_id,
		name: row.name,
		baseCurrency: row.base_currency,
	});
}

function rowToAccount(row: AccountRow): Result<Account> {
	const typeResult = AccountTypeRowSchema.safeParse(row.account_type);
	if (!typeResult.success) {
		return err(`Invalid account_type JSON for account ${row.id}: ${typeResult.error.message}`);
	}
	const accountType = typeResult.data satisfies AccountType;
	return ok({
		id: makeAccountId(row.id),
		workspaceId: makeWorkspaceId(row.workspace_id),
		name: row.name,
		icon: row.icon,
		description: row.description,
		category: row.category,
		enabled: row.enabled,
		accountType,
	});
}

function rowToJournalEntry(row: JournalEntryRow): Result<JournalEntry> {
	const liResult = LineItemsRowSchema.safeParse(row.line_items);
	if (!liResult.success) {
		return err(`Invalid line_items JSON for entry ${row.id}: ${liResult.error.message}`);
	}
	const parsed = liResult.data;
	// Apply branded ID constructors — Zod parses accountFrom/accountTo as plain strings
	const lineItems: LineItems = {
		...parsed,
		accountFrom: makeAccountId(parsed.accountFrom),
		accountTo: makeAccountId(parsed.accountTo),
	};
	return ok({
		id: makeEntryId(row.id),
		workspaceId: makeWorkspaceId(row.workspace_id),
		date: typeof row.date === "string" ? row.date.slice(0, 10) : String(row.date),
		lineItems,
	});
}

// ── Workspaces ────────────────────────────────────────────────────────────

export async function listWorkspaces(customerId: string): Promise<Result<Workspace[]>> {
	return withDbSpan("db.list.workspaces", async () => {
		const rows = await sql<WorkspaceRow[]>`
      SELECT id, customer_id, name, base_currency, expiry, request_id
      FROM workspaces
      WHERE customer_id = ${customerId}
      ORDER BY name
    `;
		const workspaces: Workspace[] = [];
		for (const row of rows) {
			const result = rowToWorkspace(row);
			if (!result.success) return result;
			workspaces.push(result.value);
		}
		return ok(workspaces);
	});
}

export async function getWorkspaceById(
	id: string,
	customerId: string,
): Promise<Result<Workspace | null>> {
	return withDbSpan("db.get.workspace", async () => {
		const rows = await sql<WorkspaceRow[]>`
      SELECT id, customer_id, name, base_currency, expiry, request_id
      FROM workspaces
      WHERE id = ${id} AND customer_id = ${customerId}
      LIMIT 1
    `;
		if (rows.length === 0) return ok(null);
		return rowToWorkspace(rows[0]);
	});
}

export async function insertWorkspace(params: {
	customerId: string;
	name: string;
	baseCurrency: string;
	requestId: string;
}): Promise<Result<Workspace>> {
	const id = generateWorkspaceId();
	const expiry = optimisticExpiry();
	const currencyName = getCurrencyName(params.baseCurrency);

	return withDbSpan("db.insert.workspace", async () => {
		await sql.begin(async (tx) => {
			await tx`
        INSERT INTO workspaces (id, customer_id, name, base_currency, expiry, request_id)
        VALUES (${id}, ${params.customerId}, ${params.name}, ${params.baseCurrency}, ${expiry}, ${params.requestId})
      `;
			// Seed the per-workspace currency list with the base currency
			await tx`
        INSERT INTO workspace_currencies (workspace_id, customer_id, currency_code, currency_name)
        VALUES (${id}, ${params.customerId}, ${params.baseCurrency}, ${currencyName})
        ON CONFLICT (workspace_id, currency_code) DO NOTHING
      `;
			// Seed an empty balance snapshot
			await tx`
        INSERT INTO balance_snapshots (workspace_id, customer_id, balance_of_accounts)
        VALUES (${id}, ${params.customerId}, '{}')
        ON CONFLICT (workspace_id) DO NOTHING
      `;
		});
		return ok({
			id,
			customerId: params.customerId,
			name: params.name,
			baseCurrency: params.baseCurrency,
		});
	});
}

// ── Workspace currencies ──────────────────────────────────────────────────

export async function listWorkspaceCurrencies(
	workspaceId: string,
	customerId: string,
): Promise<Result<WorkspaceCurrency[]>> {
	return withDbSpan("db.list.workspace_currencies", async () => {
		const rows = await sql<WorkspaceCurrencyRow[]>`
      SELECT workspace_id, customer_id, currency_code, currency_name
      FROM workspace_currencies
      WHERE workspace_id = ${workspaceId} AND customer_id = ${customerId}
      ORDER BY currency_code
    `;
		return ok(
			rows.map((r) => ({
				workspaceId: makeWorkspaceId(r.workspace_id),
				currencyCode: r.currency_code,
				currencyName: r.currency_name,
			})),
		);
	});
}

export async function insertWorkspaceCurrency(params: {
	workspaceId: string;
	customerId: string;
	currencyCode: string;
	currencyName: string;
}): Promise<Result<WorkspaceCurrency>> {
	return withDbSpan("db.insert.workspace_currency", async () => {
		await sql`
      INSERT INTO workspace_currencies (workspace_id, customer_id, currency_code, currency_name)
      VALUES (${params.workspaceId}, ${params.customerId}, ${params.currencyCode}, ${params.currencyName})
      ON CONFLICT (workspace_id, currency_code) DO NOTHING
    `;
		return ok({
			workspaceId: makeWorkspaceId(params.workspaceId),
			currencyCode: params.currencyCode,
			currencyName: params.currencyName,
		});
	});
}

// ── Accounts ──────────────────────────────────────────────────────────────

export async function listAccounts(
	workspaceId: string,
	customerId: string,
): Promise<Result<Account[]>> {
	return withDbSpan("db.list.accounts", async () => {
		const rows = await sql<AccountRow[]>`
      SELECT id, workspace_id, customer_id, name, icon, description, category, enabled, account_type, expiry, request_id
      FROM accounts
      WHERE workspace_id = ${workspaceId} AND customer_id = ${customerId}
      ORDER BY name
    `;
		const accounts: Account[] = [];
		for (const row of rows) {
			const result = rowToAccount(row);
			if (!result.success) return result;
			accounts.push(result.value);
		}
		return ok(accounts);
	});
}

export async function getAccountById(
	id: string,
	workspaceId: string,
	customerId: string,
): Promise<Result<Account | null>> {
	return withDbSpan("db.get.account", async () => {
		const rows = await sql<AccountRow[]>`
      SELECT id, workspace_id, customer_id, name, icon, description, category, enabled, account_type, expiry, request_id
      FROM accounts
      WHERE id = ${id} AND workspace_id = ${workspaceId} AND customer_id = ${customerId}
      LIMIT 1
    `;
		if (rows.length === 0) return ok(null);
		return rowToAccount(rows[0]);
	});
}

export async function insertAccount(params: {
	workspaceId: string;
	customerId: string;
	name: string;
	icon: string;
	description: string;
	category: string;
	accountType: AccountType;
	requestId: string;
}): Promise<Result<Account>> {
	const id = generateAccountId();
	const expiry = optimisticExpiry();
	const accountTypeJson = JSON.stringify(params.accountType);

	return withDbSpan("db.insert.account", async () => {
		await sql`
      INSERT INTO accounts (id, workspace_id, customer_id, name, icon, description, category, enabled, account_type, expiry, request_id)
      VALUES (${id}, ${params.workspaceId}, ${params.customerId}, ${params.name}, ${params.icon}, ${params.description}, ${params.category}, TRUE, ${accountTypeJson}::jsonb, ${expiry}, ${params.requestId})
    `;
		return ok({
			id,
			workspaceId: makeWorkspaceId(params.workspaceId),
			name: params.name,
			icon: params.icon,
			description: params.description,
			category: params.category,
			enabled: true,
			accountType: params.accountType,
		});
	});
}

export async function updateAccount(params: {
	id: string;
	workspaceId: string;
	customerId: string;
	name: string;
	icon: string;
	description: string;
	category: string;
	enabled: boolean;
	requestId: string;
}): Promise<Result<void>> {
	const expiry = optimisticExpiry();

	return withDbSpan("db.update.account", async () => {
		const result = await sql`
      UPDATE accounts
      SET name = ${params.name}, icon = ${params.icon}, description = ${params.description},
          category = ${params.category}, enabled = ${params.enabled},
          expiry = ${expiry}, request_id = ${params.requestId}
      WHERE id = ${params.id} AND workspace_id = ${params.workspaceId} AND customer_id = ${params.customerId}
    `;
		if (result.count === 0) return err("Account not found");
		return ok(undefined);
	});
}

// Disabling an account hides it from the main view without breaking history.
// Accounts with existing journal entries cannot be fully deleted since the
// entries reference them; disable/enable is the intended lifecycle.
export async function setAccountEnabled(params: {
	id: string;
	workspaceId: string;
	customerId: string;
	enabled: boolean;
}): Promise<Result<void>> {
	return withDbSpan("db.set_account_enabled", async () => {
		const result = await sql`
      UPDATE accounts
      SET enabled = ${params.enabled}
      WHERE id = ${params.id} AND workspace_id = ${params.workspaceId} AND customer_id = ${params.customerId}
    `;
		if (result.count === 0) return err("Account not found");
		return ok(undefined);
	});
}

// ── Journal entries ───────────────────────────────────────────────────────

export async function listJournalEntries(
	workspaceId: string,
	customerId: string,
): Promise<Result<JournalEntry[]>> {
	return withDbSpan("db.list.journal_entries", async () => {
		const rows = await sql<JournalEntryRow[]>`
      SELECT id, workspace_id, customer_id, date, line_items, expiry, request_id
      FROM journal_entries
      WHERE workspace_id = ${workspaceId} AND customer_id = ${customerId}
      ORDER BY date DESC, id DESC
    `;
		const entries: JournalEntry[] = [];
		for (const row of rows) {
			const result = rowToJournalEntry(row);
			if (!result.success) return result;
			entries.push(result.value);
		}
		return ok(entries);
	});
}

export async function listJournalEntriesForAccount(
	accountId: string,
	workspaceId: string,
	customerId: string,
): Promise<Result<JournalEntry[]>> {
	return withDbSpan("db.list.journal_entries_for_account", async () => {
		const rows = await sql<JournalEntryRow[]>`
      SELECT je.id, je.workspace_id, je.customer_id, je.date, je.line_items, je.expiry, je.request_id
      FROM journal_entries je
      INNER JOIN journal_entry_account_transactions jeat
        ON jeat.journal_entry_id = je.id
       AND jeat.account_id = ${accountId}
      WHERE je.workspace_id = ${workspaceId} AND je.customer_id = ${customerId}
      ORDER BY je.date DESC, je.id DESC
    `;
		const entries: JournalEntry[] = [];
		for (const row of rows) {
			const result = rowToJournalEntry(row);
			if (!result.success) return result;
			entries.push(result.value);
		}
		return ok(entries);
	});
}

export async function getBalanceSnapshot(
	workspaceId: string,
	customerId: string,
): Promise<Result<BalanceMap>> {
	return withDbSpan("db.get.balance_snapshot", async () => {
		const rows = await sql<BalanceSnapshotRow[]>`
      SELECT workspace_id, customer_id, balance_of_accounts
      FROM balance_snapshots
      WHERE workspace_id = ${workspaceId} AND customer_id = ${customerId}
      LIMIT 1
    `;
		if (rows.length === 0) return ok({} satisfies BalanceMap);
		const parsed = BalanceMapSchema.safeParse(rows[0].balance_of_accounts);
		if (!parsed.success) {
			return err(`Invalid balance_of_accounts JSON: ${parsed.error.message}`);
		}
		return ok(parsed.data);
	});
}

export async function insertJournalEntry(params: {
	workspaceId: string;
	customerId: string;
	date: string;
	lineItems: LineItems;
	requestId: string;
}): Promise<Result<JournalEntry>> {
	const id = generateEntryId();
	const expiry = optimisticExpiry();
	const lineItemsJson = JSON.stringify(params.lineItems);

	return withDbSpan("db.insert.journal_entry", async () => {
		// Compute denormalized account transactions
		const txs = computeAccountTransactions(
			id,
			makeWorkspaceId(params.workspaceId),
			params.customerId,
			params.lineItems,
		);

		await sql.begin(async (tx) => {
			// Insert the journal entry
			await tx`
        INSERT INTO journal_entries (id, workspace_id, customer_id, date, line_items, expiry, request_id)
        VALUES (${id}, ${params.workspaceId}, ${params.customerId}, ${params.date}, ${lineItemsJson}::jsonb, ${expiry}, ${params.requestId})
      `;

			// Insert denormalized transaction rows
			for (const t of txs) {
				await tx`
          INSERT INTO journal_entry_account_transactions
            (journal_entry_id, workspace_id, customer_id, account_id, currency_code, increase, decrease)
          VALUES
            (${t.journalEntryId}, ${t.workspaceId}, ${params.customerId}, ${t.accountId}, ${t.currencyCode}, ${t.increase}, ${t.decrease})
          ON CONFLICT (journal_entry_id, account_id, currency_code) DO UPDATE
            SET increase = EXCLUDED.increase, decrease = EXCLUDED.decrease
        `;
			}

			// Fetch and update balance snapshot within the same transaction
			const snapshotRows = await tx<BalanceSnapshotRow[]>`
        SELECT balance_of_accounts FROM balance_snapshots
        WHERE workspace_id = ${params.workspaceId}
        FOR UPDATE
      `;

			const currentBalance: BalanceMap =
				snapshotRows.length > 0
					? (BalanceMapSchema.safeParse(snapshotRows[0].balance_of_accounts).data ?? {})
					: {};

			const newBalance = applyTransactionsToBalance(currentBalance, txs, 1);
			const newBalanceJson = JSON.stringify(newBalance);

			await tx`
        INSERT INTO balance_snapshots (workspace_id, customer_id, balance_of_accounts)
        VALUES (${params.workspaceId}, ${params.customerId}, ${newBalanceJson}::jsonb)
        ON CONFLICT (workspace_id) DO UPDATE
          SET balance_of_accounts = EXCLUDED.balance_of_accounts
      `;
		});

		return ok({
			id,
			workspaceId: makeWorkspaceId(params.workspaceId),
			date: params.date,
			lineItems: params.lineItems,
		});
	});
}

export async function updateJournalEntry(params: {
	id: string;
	workspaceId: string;
	customerId: string;
	date: string;
	lineItems: LineItems;
	requestId: string;
}): Promise<Result<void>> {
	const expiry = optimisticExpiry();
	const lineItemsJson = JSON.stringify(params.lineItems);

	return withDbSpan("db.update.journal_entry", async () => {
		const newTxs = computeAccountTransactions(
			makeEntryId(params.id),
			makeWorkspaceId(params.workspaceId),
			params.customerId,
			params.lineItems,
		);

		await sql.begin(async (tx) => {
			// Fetch old line items so we can revert their effect on the balance
			const oldRows = await tx<JournalEntryRow[]>`
        SELECT line_items FROM journal_entries
        WHERE id = ${params.id} AND workspace_id = ${params.workspaceId} AND customer_id = ${params.customerId}
        FOR UPDATE
      `;
			if (oldRows.length === 0) throw new Error("Journal entry not found");

			const oldLineItemsResult = LineItemsRowSchema.safeParse(oldRows[0].line_items);
			if (!oldLineItemsResult.success) {
				throw new Error(`Cannot parse old line_items: ${oldLineItemsResult.error.message}`);
			}
			const oldParsed = oldLineItemsResult.data;
			const oldLineItems: LineItems = {
				...oldParsed,
				accountFrom: makeAccountId(oldParsed.accountFrom),
				accountTo: makeAccountId(oldParsed.accountTo),
			};
			const oldTxs = computeAccountTransactions(
				makeEntryId(params.id),
				makeWorkspaceId(params.workspaceId),
				params.customerId,
				oldLineItems,
			);

			// Update the journal entry
			await tx`
        UPDATE journal_entries
        SET date = ${params.date}, line_items = ${lineItemsJson}::jsonb, expiry = ${expiry}, request_id = ${params.requestId}
        WHERE id = ${params.id} AND workspace_id = ${params.workspaceId} AND customer_id = ${params.customerId}
      `;

			// Replace denormalized transaction rows
			await tx`
        DELETE FROM journal_entry_account_transactions
        WHERE journal_entry_id = ${params.id} AND workspace_id = ${params.workspaceId}
      `;
			for (const t of newTxs) {
				await tx`
          INSERT INTO journal_entry_account_transactions
            (journal_entry_id, workspace_id, customer_id, account_id, currency_code, increase, decrease)
          VALUES
            (${t.journalEntryId}, ${t.workspaceId}, ${params.customerId}, ${t.accountId}, ${t.currencyCode}, ${t.increase}, ${t.decrease})
        `;
			}

			// Revert old, apply new to balance snapshot
			const snapshotRows = await tx<BalanceSnapshotRow[]>`
        SELECT balance_of_accounts FROM balance_snapshots
        WHERE workspace_id = ${params.workspaceId}
        FOR UPDATE
      `;
			const currentBalance: BalanceMap =
				snapshotRows.length > 0
					? (BalanceMapSchema.safeParse(snapshotRows[0].balance_of_accounts).data ?? {})
					: {};

			const afterRevert = applyTransactionsToBalance(currentBalance, oldTxs, -1);
			const newBalance = applyTransactionsToBalance(afterRevert, newTxs, 1);
			const newBalanceJson = JSON.stringify(newBalance);

			await tx`
        INSERT INTO balance_snapshots (workspace_id, customer_id, balance_of_accounts)
        VALUES (${params.workspaceId}, ${params.customerId}, ${newBalanceJson}::jsonb)
        ON CONFLICT (workspace_id) DO UPDATE
          SET balance_of_accounts = EXCLUDED.balance_of_accounts
      `;
		});

		return ok(undefined);
	});
}

export async function deleteJournalEntry(params: {
	id: string;
	workspaceId: string;
	customerId: string;
}): Promise<Result<void>> {
	return withDbSpan("db.delete.journal_entry", async () => {
		await sql.begin(async (tx) => {
			const rows = await tx<JournalEntryRow[]>`
        SELECT line_items FROM journal_entries
        WHERE id = ${params.id} AND workspace_id = ${params.workspaceId} AND customer_id = ${params.customerId}
        FOR UPDATE
      `;
			if (rows.length === 0) throw new Error("Journal entry not found");

			const liResult = LineItemsRowSchema.safeParse(rows[0].line_items);
			if (!liResult.success) {
				throw new Error(`Cannot parse line_items: ${liResult.error.message}`);
			}
			const parsed = liResult.data;
			const lineItems: LineItems = {
				...parsed,
				accountFrom: makeAccountId(parsed.accountFrom),
				accountTo: makeAccountId(parsed.accountTo),
			};
			const txs = computeAccountTransactions(
				makeEntryId(params.id),
				makeWorkspaceId(params.workspaceId),
				params.customerId,
				lineItems,
			);

			await tx`
        DELETE FROM journal_entry_account_transactions
        WHERE journal_entry_id = ${params.id} AND workspace_id = ${params.workspaceId}
      `;
			await tx`
        DELETE FROM journal_entries
        WHERE id = ${params.id} AND workspace_id = ${params.workspaceId} AND customer_id = ${params.customerId}
      `;

			const snapshotRows = await tx<BalanceSnapshotRow[]>`
        SELECT balance_of_accounts FROM balance_snapshots
        WHERE workspace_id = ${params.workspaceId}
        FOR UPDATE
      `;
			const currentBalance: BalanceMap =
				snapshotRows.length > 0
					? (BalanceMapSchema.safeParse(snapshotRows[0].balance_of_accounts).data ?? {})
					: {};

			const newBalance = applyTransactionsToBalance(currentBalance, txs, -1);
			const newBalanceJson = JSON.stringify(newBalance);

			await tx`
        INSERT INTO balance_snapshots (workspace_id, customer_id, balance_of_accounts)
        VALUES (${params.workspaceId}, ${params.customerId}, ${newBalanceJson}::jsonb)
        ON CONFLICT (workspace_id) DO UPDATE
          SET balance_of_accounts = EXCLUDED.balance_of_accounts
      `;
		});

		return ok(undefined);
	});
}
