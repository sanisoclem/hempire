import { error, redirect } from "@sveltejs/kit";
import { requireOnboarded } from "$lib/server/guards";
import { getWorkspaceById } from "$lib/server/finance";
import { ROUTES } from "$lib/routes";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ cookies, params }) => {
	const { customerId } = requireOnboarded(cookies);
	const result = await getWorkspaceById(params.workspaceId, customerId);
	if (!result.success) throw error(500, result.error);
	if (!result.value) throw error(404, "Workspace not found");

	redirect(302, ROUTES.workspace.sync(params.workspaceId));
};
