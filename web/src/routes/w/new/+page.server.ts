import { redirect, fail } from "@sveltejs/kit";
import { requireOnboarded } from "$lib/server/guards";
import { insertWorkspace } from "$lib/server/finance";
import { CreateWorkspaceSchema } from "$lib/schemas";
import { ROUTES } from "$lib/routes";
import type { PageServerLoad, Actions } from "./$types";

export const load: PageServerLoad = async ({ cookies }) => {
	requireOnboarded(cookies);
};

export const actions: Actions = {
	default: async ({ cookies, request }) => {
		const { customerId } = requireOnboarded(cookies);

		const data = await request.formData();
		const raw = {
			name: data.get("name"),
			baseCurrency: data.get("baseCurrency"),
		};

		const parsed = CreateWorkspaceSchema.safeParse(raw);
		if (!parsed.success) {
			const firstError = parsed.error.errors[0];
			return fail(422, { error: firstError?.message ?? "Invalid input" });
		}

		const result = await insertWorkspace({
			customerId,
			name: parsed.data.name,
			baseCurrency: parsed.data.baseCurrency,
			requestId: crypto.randomUUID(),
		});

		if (!result.success) return fail(500, { error: result.error });

		redirect(302, ROUTES.workspace.detail(result.value.id));
	},
};
