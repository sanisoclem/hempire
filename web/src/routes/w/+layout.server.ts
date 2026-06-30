import { requireOnboarded } from "$lib/server/guards";
import { getLedgers } from "$lib/server/ledger";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ cookies }) => {
	const { userName } = requireOnboarded(cookies);
	const workspaces = getLedgers();
	return { workspaces, user: { userName } };
};
