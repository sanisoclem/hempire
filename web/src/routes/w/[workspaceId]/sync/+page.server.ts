import { error, fail } from "@sveltejs/kit";
import { requireOnboarded } from "$lib/server/guards";
import {
	listAccounts,
	getBalanceSnapshot,
	insertAccount,
	updateAccount,
	setAccountEnabled,
	insertWorkspaceCurrency,
} from "$lib/server/finance";
import { CreateAccountSchema, UpdateAccountSchema, AddWorkspaceCurrencySchema } from "$lib/schemas";
import { getCurrencyName } from "$lib/currencies";
import type { PageServerLoad, Actions } from "./$types";

export const load: PageServerLoad = async ({ cookies, params }) => {
	const { customerId } = requireOnboarded(cookies);
	const { workspaceId } = params;

	const [accountsResult, balanceResult] = await Promise.all([
		listAccounts(workspaceId, customerId),
		getBalanceSnapshot(workspaceId, customerId),
	]);

	if (!accountsResult.success) throw error(500, accountsResult.error);
	if (!balanceResult.success) throw error(500, balanceResult.error);

	return {
		accounts: accountsResult.value,
		balanceMap: balanceResult.value,
	};
};

export const actions: Actions = {
	createAccount: async ({ cookies, params, request }) => {
		const { customerId } = requireOnboarded(cookies);
		const { workspaceId } = params;

		const data = await request.formData();
		const accountTypeRaw = data.get("accountType");

		let accountTypeParsed: unknown;
		try {
			accountTypeParsed = JSON.parse(typeof accountTypeRaw === "string" ? accountTypeRaw : "null");
		} catch {
			return fail(422, { action: "createAccount", error: "Invalid account type format" });
		}

		const parsed = CreateAccountSchema.safeParse({
			workspaceId,
			name: data.get("name"),
			icon: data.get("icon") ?? "",
			description: data.get("description") ?? "",
			category: data.get("category") ?? "",
			accountType: accountTypeParsed,
		});

		if (!parsed.success) {
			const firstError = parsed.error.errors[0];
			return fail(422, { action: "createAccount", error: firstError?.message ?? "Invalid input" });
		}

		const result = await insertAccount({
			workspaceId,
			customerId,
			name: parsed.data.name,
			icon: parsed.data.icon,
			description: parsed.data.description,
			category: parsed.data.category,
			accountType: parsed.data.accountType,
			requestId: crypto.randomUUID(),
		});

		if (!result.success) return fail(500, { action: "createAccount", error: result.error });
		return { action: "createAccount", success: true };
	},

	updateAccount: async ({ cookies, params, request }) => {
		const { customerId } = requireOnboarded(cookies);
		const { workspaceId } = params;

		const data = await request.formData();

		const parsed = UpdateAccountSchema.safeParse({
			id: data.get("id"),
			workspaceId,
			name: data.get("name"),
			icon: data.get("icon") ?? "",
			description: data.get("description") ?? "",
			category: data.get("category") ?? "",
			enabled: data.get("enabled") !== "false",
		});

		if (!parsed.success) {
			const firstError = parsed.error.errors[0];
			return fail(422, { action: "updateAccount", error: firstError?.message ?? "Invalid input" });
		}

		const result = await updateAccount({
			...parsed.data,
			customerId,
			requestId: crypto.randomUUID(),
		});

		if (!result.success) return fail(500, { action: "updateAccount", error: result.error });
		return { action: "updateAccount", success: true };
	},

	addCurrency: async ({ cookies, params, request }) => {
		const { customerId } = requireOnboarded(cookies);
		const { workspaceId } = params;

		const data = await request.formData();
		const currencyCode = String(data.get("currencyCode") ?? "").toUpperCase();

		const parsed = AddWorkspaceCurrencySchema.safeParse({
			workspaceId,
			currencyCode,
			currencyName: getCurrencyName(currencyCode),
		});

		if (!parsed.success) {
			const firstError = parsed.error.errors[0];
			return fail(422, { action: "addCurrency", error: firstError?.message ?? "Invalid currency" });
		}

		const result = await insertWorkspaceCurrency({
			workspaceId: parsed.data.workspaceId,
			customerId,
			currencyCode: parsed.data.currencyCode,
			currencyName: parsed.data.currencyName,
		});

		if (!result.success) return fail(500, { action: "addCurrency", error: result.error });
		return { action: "addCurrency", success: true };
	},

	toggleAccount: async ({ cookies, params, request }) => {
		const { customerId } = requireOnboarded(cookies);
		const { workspaceId } = params;

		const data = await request.formData();
		const id = String(data.get("id") ?? "");
		const enabled = data.get("enabled") !== "false";
		if (!id) return fail(422, { action: "toggleAccount", error: "Missing account id" });

		const result = await setAccountEnabled({ id, workspaceId, customerId, enabled });
		if (!result.success) return fail(500, { action: "toggleAccount", error: result.error });
		return { action: "toggleAccount", success: true };
	},
};
