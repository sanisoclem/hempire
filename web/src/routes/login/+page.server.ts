import { redirect } from "@sveltejs/kit";
import { createAuthorizationUrl } from "$lib/server/zitadel";
import type { Actions } from "./$types";

export const actions: Actions = {
	default: async ({ cookies }) => {
		redirect(302, createAuthorizationUrl(cookies).toString());
	},
};
