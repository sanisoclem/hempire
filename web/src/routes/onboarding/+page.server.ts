import { redirect, fail } from "@sveltejs/kit";
import { requireAuthenticated } from "$lib/server/guards";
import { onboard, CrmError } from "$lib/server/crm";
import { refreshTokens } from "$lib/server/zitadel";
import { updateSession } from "$lib/server/session";
import { ROUTES } from "$lib/routes";
import type { PageServerLoad, Actions } from "./$types";

export const load: PageServerLoad = async ({ url, cookies }) => {
	const { userName, customerId } = requireAuthenticated(cookies);
	if (customerId) redirect(302, ROUTES.home);
	return { inviteId: url.searchParams.get("invite") ?? null, userName };
};

export const actions: Actions = {
	default: async ({ request, cookies }) => {
		const { accessToken, refreshToken, sessionId } = requireAuthenticated(cookies);

		const data = await request.formData();
		const inviteId = data.get("inviteId");
		if (typeof inviteId !== "string" || !inviteId.trim()) {
			return fail(400, { error: "Invite code is required" });
		}

		try {
			await onboard(accessToken, inviteId.trim());
		} catch (err) {
			if (err instanceof CrmError) return fail(err.status, { error: err.clientMessage });
			console.error("[onboarding] unexpected error:", err);
			return fail(500, { error: "Internal error" });
		}

		try {
			const newTokens = await refreshTokens(refreshToken);
			updateSession(sessionId, {
				accessToken: newTokens.accessToken,
				refreshToken: newTokens.refreshToken,
				idToken: newTokens.idToken,
				tokenExpiry: newTokens.tokenExpiry,
				customerId: newTokens.claims.customerId ?? null,
			});
		} catch (err) {
			console.warn("[onboarding] token refresh failed, session will not reflect customer_id:", err);
		}

		redirect(302, ROUTES.home);
	},
};
