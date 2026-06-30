import { redirect } from "@sveltejs/kit";
import { error } from "@sveltejs/kit";
import { getSessionFromCookies } from "$lib/server/session";
import { listWorkspaces } from "$lib/server/finance";
import { ROUTES } from "$lib/routes";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ cookies }) => {
	const result = getSessionFromCookies(cookies);
	if (!result) redirect(302, ROUTES.login);
	if (!result.session.customerId) redirect(302, ROUTES.onboarding);

	const wsResult = await listWorkspaces(result.session.customerId);
	if (!wsResult.success) throw error(500, wsResult.error);

	if (wsResult.value.length === 0) redirect(302, ROUTES.workspace.new);
	redirect(302, ROUTES.workspace.detail(wsResult.value[0].id));
};
