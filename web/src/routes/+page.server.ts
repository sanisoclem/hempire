import { redirect } from "@sveltejs/kit";
import { getSessionFromCookies } from "$lib/server/session";
import { getLedgers } from "$lib/server/ledger";
import { ROUTES } from "$lib/routes";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ cookies }) => {
	const result = getSessionFromCookies(cookies);
	if (!result) redirect(302, ROUTES.login);
	if (!result.session.customerId) redirect(302, ROUTES.onboarding);

	const ledgers = getLedgers();
	if (ledgers.length === 0) redirect(302, ROUTES.workspace.new);
	redirect(302, ROUTES.workspace.detail(ledgers[0].id));
};
