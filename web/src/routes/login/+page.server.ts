import { redirect } from "@sveltejs/kit";
import { createAuthorizationUrl } from "$lib/server/zitadel";
import { getSessionFromCookies } from "$lib/server/session";
import { ROUTES } from "$lib/routes";
import type { Actions, PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ cookies }) => {
	if (getSessionFromCookies(cookies)) redirect(302, ROUTES.home);
};

export const actions: Actions = {
	default: async ({ cookies }) => {
		redirect(302, createAuthorizationUrl(cookies).toString());
	},
};
