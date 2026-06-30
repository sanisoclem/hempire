import { redirect, fail } from "@sveltejs/kit";
import { requireOnboarded } from "$lib/server/guards";
import { createLedger } from "$lib/server/ledger";
import { ROUTES } from "$lib/routes";
import type { PageServerLoad, Actions } from "./$types";

export const load: PageServerLoad = async ({ cookies }) => {
	requireOnboarded(cookies);
};

export const actions: Actions = {
	default: async ({ cookies, request }) => {
		requireOnboarded(cookies);

		const data = await request.formData();
		const name = data.get("name");
		const baseCurrency = data.get("baseCurrency");

		if (!name || typeof name !== "string" || name.trim() === "") {
			return fail(422, { error: "Workspace name is required." });
		}
		if (!baseCurrency || typeof baseCurrency !== "string" || baseCurrency.trim() === "") {
			return fail(422, { error: "Base currency is required." });
		}

		const ledger = createLedger(name.trim(), baseCurrency.trim());
		redirect(302, ROUTES.workspace.detail(ledger.id));
	},
};
