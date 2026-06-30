import { redirect } from "@sveltejs/kit";
import { getSessionFromCookies, deleteSession, SESSION_COOKIE_NAME } from "$lib/server/session";
import { ROUTES } from "$lib/routes";
import type { Actions } from "./$types";

export const actions: Actions = {
	default: async ({ cookies }) => {
		const result = getSessionFromCookies(cookies);
		if (result) deleteSession(result.sessionId);
		cookies.delete(SESSION_COOKIE_NAME, { path: "/" });
		redirect(302, ROUTES.login);
	},
};
