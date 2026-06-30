// Domain types for the finance module.
// Branded IDs prevent accidental cross-type ID usage without runtime overhead.
// All sum types are discriminated unions — invalid states cannot be constructed.

type Branded<T, B> = T & { readonly __brand: B };

export type WorkspaceId = Branded<string, "WorkspaceId">;
export type AccountId = Branded<string, "AccountId">;
export type EntryId = Branded<string, "EntryId">;
export type CurrencyCode = Branded<string, "CurrencyCode">;

export function makeWorkspaceId(raw: string): WorkspaceId {
	return raw as WorkspaceId;
}
export function makeAccountId(raw: string): AccountId {
	return raw as AccountId;
}
export function makeEntryId(raw: string): EntryId {
	return raw as EntryId;
}
export function makeCurrencyCode(raw: string): CurrencyCode {
	return raw as CurrencyCode;
}

export function generateWorkspaceId(): WorkspaceId {
	return makeWorkspaceId(`ws_${crypto.randomUUID().replace(/-/g, "")}`);
}
export function generateAccountId(): AccountId {
	return makeAccountId(`acc_${crypto.randomUUID().replace(/-/g, "")}`);
}
export function generateEntryId(): EntryId {
	return makeEntryId(`tx_${crypto.randomUUID().replace(/-/g, "")}`);
}

// AccountType — which kind of account is this?
//   CashAccount: holds money in one currency (checking, savings, etc.)
//   External: represents income sources or expense categories (no balance)
//   FxExchanger: system account used for currency exchange balancing (hidden from users)
export type AccountType =
	| { readonly kind: "CashAccount"; readonly currency: string; readonly canHaveAssets: boolean }
	| { readonly kind: "External"; readonly subType: "Income" | "Expense" }
	| { readonly kind: "FxExchanger" };

// LineItems — the payload of a journal entry
export type SameCurrencyTransfer = {
	readonly kind: "SameCurrencyTransfer";
	readonly amount: string; // decimal string, always positive
	readonly currency: string; // currency code, e.g. "USD"
	readonly accountFrom: AccountId;
	readonly accountTo: AccountId;
};

export type LineItems = SameCurrencyTransfer; // FxTransfer will be added later

// Derived account transactions from a journal entry.
// One row per (journal_entry, account, currency).
export type AccountTransaction = {
	readonly journalEntryId: EntryId;
	readonly workspaceId: WorkspaceId;
	readonly accountId: AccountId;
	readonly currencyCode: string; // currency code, e.g. "USD"
	readonly increase: string; // decimal string
	readonly decrease: string; // decimal string
};

// Per-currency balance for one account
export type AccountBalance = {
	readonly increase: string;
	readonly decrease: string;
	readonly balance: string; // increase - decrease
};

// Full balance map: accountId → currencyCode → AccountBalance
export type BalanceMap = Readonly<Record<string, Readonly<Record<string, AccountBalance>>>>;

export type Workspace = {
	readonly id: WorkspaceId;
	readonly customerId: string;
	readonly name: string;
	readonly baseCurrency: string; // currency code, e.g. "USD"
};

export type WorkspaceCurrency = {
	readonly workspaceId: WorkspaceId;
	readonly currencyCode: string; // currency code, e.g. "USD"
	readonly currencyName: string;
};

export type Account = {
	readonly id: AccountId;
	readonly workspaceId: WorkspaceId;
	readonly name: string;
	readonly icon: string;
	readonly description: string;
	readonly category: string;
	readonly enabled: boolean;
	readonly accountType: AccountType;
};

export type JournalEntry = {
	readonly id: EntryId;
	readonly workspaceId: WorkspaceId;
	readonly date: string; // ISO date string YYYY-MM-DD
	readonly lineItems: LineItems;
};

// Compute account transactions from a SameCurrencyTransfer line item.
// Returns the two rows to insert into journal_entry_account_transactions.
export function computeAccountTransactions(
	entryId: EntryId,
	workspaceId: WorkspaceId,
	customerId: string,
	lineItems: SameCurrencyTransfer,
): AccountTransaction[] {
	return [
		{
			journalEntryId: entryId,
			workspaceId,
			accountId: lineItems.accountFrom,
			currencyCode: lineItems.currency,
			increase: "0",
			decrease: lineItems.amount,
		},
		{
			journalEntryId: entryId,
			workspaceId,
			accountId: lineItems.accountTo,
			currencyCode: lineItems.currency,
			increase: lineItems.amount,
			decrease: "0",
		},
	];
}

// Apply a list of account transactions to an existing balance map, returning the updated map.
// sign: +1 to add, -1 to revert.
export function applyTransactionsToBalance(
	current: BalanceMap,
	txs: AccountTransaction[],
	sign: 1 | -1,
): BalanceMap {
	const result: Record<string, Record<string, AccountBalance>> = {};

	// Deep-clone existing map
	for (const [accId, currencies] of Object.entries(current)) {
		result[accId] = {};
		for (const [code, bal] of Object.entries(currencies)) {
			result[accId][code] = bal;
		}
	}

	for (const tx of txs) {
		const accId = tx.accountId;
		const code = tx.currencyCode;

		if (!result[accId]) result[accId] = {};

		const prev = result[accId][code] ?? { increase: "0", decrease: "0", balance: "0" };
		const inc = parseFloat(prev.increase) + sign * parseFloat(tx.increase);
		const dec = parseFloat(prev.decrease) + sign * parseFloat(tx.decrease);
		const bal = inc - dec;

		result[accId][code] = {
			increase: inc.toFixed(8),
			decrease: dec.toFixed(8),
			balance: bal.toFixed(8),
		};
	}

	return result;
}

// Format a balance string for display (strips trailing zeros, adds sign)
export function formatBalance(balance: string, showSign = false): string {
	const num = parseFloat(balance);
	const fixed = num % 1 === 0 ? num.toFixed(2) : num.toFixed(8).replace(/0+$/, "");
	if (showSign && num > 0) return `+${fixed}`;
	return fixed;
}

// Label helpers
export function accountTypeLabel(t: AccountType): string {
	switch (t.kind) {
		case "CashAccount":
			return `Cash (${t.currency})`;
		case "External":
			return t.subType === "Income" ? "Income" : "Expense";
		case "FxExchanger":
			return "FX";
	}
}
