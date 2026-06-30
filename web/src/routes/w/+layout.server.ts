import { error } from "@sveltejs/kit";
import { requireOnboarded } from "$lib/server/guards";
import { listWorkspaces } from "$lib/server/finance";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ cookies }) => {
	const { customerId } = requireOnboarded(cookies);
	const result = await listWorkspaces(customerId);
	if (!result.success) throw error(500, result.error);
	return { workspaces: result.value };
};
