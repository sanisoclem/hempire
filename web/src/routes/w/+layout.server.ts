import { requireOnboarded } from "$lib/server/guards";
import { getLedgers } from "$lib/server/ledger";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ cookies }) => {
  requireOnboarded(cookies);
  const workspaces = getLedgers();
  return { workspaces };
};
