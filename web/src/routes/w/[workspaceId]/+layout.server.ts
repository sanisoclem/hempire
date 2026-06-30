import { error } from "@sveltejs/kit";
import { requireOnboarded } from "$lib/server/guards";
import { getWorkspaceById, listWorkspaceCurrencies } from "$lib/server/finance";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ cookies, params }) => {
	const { customerId } = requireOnboarded(cookies);

	const [wsResult, currResult] = await Promise.all([
		getWorkspaceById(params.workspaceId, customerId),
		listWorkspaceCurrencies(params.workspaceId, customerId),
	]);

	if (!wsResult.success) throw error(500, wsResult.error);
	if (!wsResult.value) throw error(404, "Workspace not found");
	if (!currResult.success) throw error(500, currResult.error);

	return {
		workspace: wsResult.value,
		currencies: currResult.value,
	};
};
