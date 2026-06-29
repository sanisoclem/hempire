import { requireOnboarded } from "$lib/server/guards";
import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ cookies }) => {
	const { customerId } = requireOnboarded(cookies);
	return { customerId };
};
