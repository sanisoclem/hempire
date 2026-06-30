// Zod schemas for all form inputs and JSONB parsing.
// Always use safeParse() — never parse() or parseAsync().

import { z } from "zod";

// ── Workspace ──────────────────────────────────────────────────────────────

export const CreateWorkspaceSchema = z.object({
	name: z.string().min(1, "Name is required").max(100),
	baseCurrency: z.string().min(2, "Currency is required").max(10).toUpperCase(),
});

// ── Workspace currency ─────────────────────────────────────────────────────

export const AddWorkspaceCurrencySchema = z.object({
	workspaceId: z.string().min(1),
	currencyCode: z.string().min(2).max(10).toUpperCase(),
	currencyName: z.string().min(1).max(60),
});

// ── Account type (discriminated union) ────────────────────────────────────

export const CashAccountTypeSchema = z.object({
	kind: z.literal("CashAccount"),
	currency: z.string().min(2).max(10).toUpperCase(),
	canHaveAssets: z.boolean(),
});

export const ExternalAccountTypeSchema = z.object({
	kind: z.literal("External"),
	subType: z.enum(["Income", "Expense"]),
});

export const FxExchangerTypeSchema = z.object({
	kind: z.literal("FxExchanger"),
});

export const AccountTypeSchema = z.discriminatedUnion("kind", [
	CashAccountTypeSchema,
	ExternalAccountTypeSchema,
	FxExchangerTypeSchema,
]);

export const CreateAccountSchema = z.object({
	workspaceId: z.string().min(1),
	name: z.string().min(1, "Name is required").max(100),
	icon: z.string().max(60).default(""),
	description: z.string().max(600).default(""),
	category: z.string().max(100).default(""),
	accountType: AccountTypeSchema,
});

export const UpdateAccountSchema = z.object({
	id: z.string().min(1),
	workspaceId: z.string().min(1),
	name: z.string().min(1, "Name is required").max(100),
	icon: z.string().max(60).default(""),
	description: z.string().max(600).default(""),
	category: z.string().max(100).default(""),
	enabled: z.boolean().default(true),
});

// ── Journal entry line items (discriminated union) ─────────────────────────

export const SameCurrencyTransferSchema = z.object({
	kind: z.literal("SameCurrencyTransfer"),
	amount: z
		.string()
		.min(1, "Amount is required")
		.refine((v) => {
			const n = parseFloat(v);
			return !isNaN(n) && n > 0;
		}, "Amount must be a positive number"),
	currency: z.string().min(2).max(10).toUpperCase(),
	accountFrom: z.string().min(1, "From account is required"),
	accountTo: z.string().min(1, "To account is required"),
});

export const LineItemsSchema = z.discriminatedUnion("kind", [SameCurrencyTransferSchema]);

export const CreateJournalEntrySchema = z.object({
	workspaceId: z.string().min(1),
	date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Date must be YYYY-MM-DD"),
	lineItems: LineItemsSchema,
});

export const UpdateJournalEntrySchema = CreateJournalEntrySchema.extend({
	id: z.string().min(1),
});

// ── JSONB row parsers ──────────────────────────────────────────────────────
// Used to parse JSONB columns coming back from the database/ElectricSQL.

export const AccountTypeRowSchema = AccountTypeSchema;

export const LineItemsRowSchema = LineItemsSchema;

// Balance snapshot JSONB: { [account_id]: { [currency_code]: { increase, decrease, balance } } }
export const AccountBalanceSchema = z.object({
	increase: z.string(),
	decrease: z.string(),
	balance: z.string(),
});

export const BalanceMapSchema = z.record(z.record(AccountBalanceSchema));

export type CreateWorkspaceInput = z.infer<typeof CreateWorkspaceSchema>;
export type AddWorkspaceCurrencyInput = z.infer<typeof AddWorkspaceCurrencySchema>;
export type CreateAccountInput = z.infer<typeof CreateAccountSchema>;
export type UpdateAccountInput = z.infer<typeof UpdateAccountSchema>;
export type CreateJournalEntryInput = z.infer<typeof CreateJournalEntrySchema>;
export type UpdateJournalEntryInput = z.infer<typeof UpdateJournalEntrySchema>;
