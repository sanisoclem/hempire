import { error, fail } from "@sveltejs/kit";
import { requireOnboarded } from "$lib/server/guards";
import {
	getAccountById,
	listAccounts,
	listJournalEntriesForAccount,
	getBalanceSnapshot,
	insertJournalEntry,
	updateJournalEntry,
	deleteJournalEntry,
} from "$lib/server/finance";
import { CreateJournalEntrySchema, UpdateJournalEntrySchema } from "$lib/schemas";
import { makeAccountId } from "$lib/domain";
import type { PageServerLoad, Actions } from "./$types";

export const load: PageServerLoad = async ({ cookies, params }) => {
	const { customerId } = requireOnboarded(cookies);
	const { workspaceId, accountId } = params;

	const [accountResult, allAccountsResult, entriesResult, balanceResult] = await Promise.all([
		getAccountById(accountId, workspaceId, customerId),
		listAccounts(workspaceId, customerId),
		listJournalEntriesForAccount(accountId, workspaceId, customerId),
		getBalanceSnapshot(workspaceId, customerId),
	]);

	if (!accountResult.success) throw error(500, accountResult.error);
	if (!accountResult.value) throw error(404, "Account not found");
	if (!allAccountsResult.success) throw error(500, allAccountsResult.error);
	if (!entriesResult.success) throw error(500, entriesResult.error);
	if (!balanceResult.success) throw error(500, balanceResult.error);

	return {
		account: accountResult.value,
		allAccounts: allAccountsResult.value,
		entries: entriesResult.value,
		balanceMap: balanceResult.value,
	};
};

export const actions: Actions = {
	createEntry: async ({ cookies, params, request }) => {
		const { customerId } = requireOnboarded(cookies);
		const { workspaceId } = params;

		const data = await request.formData();
		const lineItemsRaw = data.get("lineItems");

		let lineItemsParsed: unknown;
		try {
			lineItemsParsed = JSON.parse(
				typeof lineItemsRaw === "string" ? lineItemsRaw : "null",
			);
		} catch {
			return fail(422, { action: "createEntry", error: "Invalid line items format" });
		}

		const parsed = CreateJournalEntrySchema.safeParse({
			workspaceId,
			date: data.get("date"),
			lineItems: lineItemsParsed,
		});

		if (!parsed.success) {
			const firstError = parsed.error.errors[0];
			return fail(422, { action: "createEntry", error: firstError?.message ?? "Invalid input" });
		}

		// Validate same-account transfer guard
		if (
			parsed.data.lineItems.kind === "SameCurrencyTransfer" &&
			parsed.data.lineItems.accountFrom === parsed.data.lineItems.accountTo
		) {
			return fail(422, { action: "createEntry", error: "From and To accounts must be different" });
		}

		const result = await insertJournalEntry({
			workspaceId,
			customerId,
			date: parsed.data.date,
			lineItems: {
				...parsed.data.lineItems,
				accountFrom: makeAccountId(parsed.data.lineItems.accountFrom),
				accountTo: makeAccountId(parsed.data.lineItems.accountTo),
			},
			requestId: crypto.randomUUID(),
		});

		if (!result.success) return fail(500, { action: "createEntry", error: result.error });
		return { action: "createEntry", success: true };
	},

	updateEntry: async ({ cookies, params, request }) => {
		const { customerId } = requireOnboarded(cookies);
		const { workspaceId } = params;

		const data = await request.formData();
		const lineItemsRaw = data.get("lineItems");

		let lineItemsParsed: unknown;
		try {
			lineItemsParsed = JSON.parse(
				typeof lineItemsRaw === "string" ? lineItemsRaw : "null",
			);
		} catch {
			return fail(422, { action: "updateEntry", error: "Invalid line items format" });
		}

		const parsed = UpdateJournalEntrySchema.safeParse({
			id: data.get("id"),
			workspaceId,
			date: data.get("date"),
			lineItems: lineItemsParsed,
		});

		if (!parsed.success) {
			const firstError = parsed.error.errors[0];
			return fail(422, { action: "updateEntry", error: firstError?.message ?? "Invalid input" });
		}

		if (
			parsed.data.lineItems.kind === "SameCurrencyTransfer" &&
			parsed.data.lineItems.accountFrom === parsed.data.lineItems.accountTo
		) {
			return fail(422, { action: "updateEntry", error: "From and To accounts must be different" });
		}

		const result = await updateJournalEntry({
			id: parsed.data.id,
			workspaceId,
			customerId,
			date: parsed.data.date,
			lineItems: {
				...parsed.data.lineItems,
				accountFrom: makeAccountId(parsed.data.lineItems.accountFrom),
				accountTo: makeAccountId(parsed.data.lineItems.accountTo),
			},
			requestId: crypto.randomUUID(),
		});

		if (!result.success) return fail(500, { action: "updateEntry", error: result.error });
		return { action: "updateEntry", success: true };
	},

	deleteEntry: async ({ cookies, params, request }) => {
		const { customerId } = requireOnboarded(cookies);
		const { workspaceId } = params;

		const data = await request.formData();
		const id = String(data.get("id") ?? "");
		if (!id) return fail(422, { action: "deleteEntry", error: "Missing entry id" });

		const result = await deleteJournalEntry({ id, workspaceId, customerId });
		if (!result.success) return fail(500, { action: "deleteEntry", error: result.error });
		return { action: "deleteEntry", success: true };
	},
};
