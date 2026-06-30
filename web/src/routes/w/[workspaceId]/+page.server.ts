import { error } from "@sveltejs/kit";
import { requireOnboarded } from "$lib/server/guards";
import { getLedgerById } from "$lib/server/ledger";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ cookies, params }) => {
	requireOnboarded(cookies);

	const workspace = getLedgerById(params.workspaceId);
	if (!workspace) error(404, "Workspace not found");

	return { workspace };
};
