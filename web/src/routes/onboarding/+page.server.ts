import { redirect, fail } from "@sveltejs/kit";
import { client, tokenEndpoint, parseTokenClaims } from "$lib/server/auth";
import {
	getSession,
	updateSession,
	verifyAndExtractSessionId,
	SESSION_COOKIE_NAME,
} from "$lib/server/session";
import type { PageServerLoad, Actions } from "./$types";

const CRM_API_URL = process.env.BFF_CRM_API_URL;
if (!CRM_API_URL) throw new Error("BFF_CRM_API_URL is required");

export const load: PageServerLoad = async ({ url }) => {
	return { inviteId: url.searchParams.get("invite") ?? null };
};

export const actions: Actions = {
	default: async ({ request, cookies }) => {
		const data = await request.formData();
		const inviteId = data.get("inviteId");

		if (typeof inviteId !== "string" || !inviteId.trim()) {
			return fail(400, { error: "Invite code is required" });
		}

		const cookieValue = cookies.get(SESSION_COOKIE_NAME);
		if (!cookieValue) return fail(401, { error: "Not authenticated" });

		const sessionId = verifyAndExtractSessionId(cookieValue);
		if (!sessionId) return fail(401, { error: "Invalid session" });

		const session = getSession(sessionId);
		if (!session) return fail(401, { error: "Session not found" });

		let res: Response;
		try {
			res = await fetch(`${CRM_API_URL}/onboarding`, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					Authorization: `Bearer ${session.accessToken}`,
				},
				body: JSON.stringify({ inviteId: inviteId.trim() }),
			});
		} catch {
			return fail(502, { error: "Could not reach onboarding service" });
		}

		if (!res.ok) {
			const body = await res.json().catch(() => ({}));
			const msg = (body as { value?: string }).value ?? "Onboarding failed";
			return fail(400, { error: msg });
		}

		// Refresh token so the new customer_id claim is included
		try {
			const newTokens = await client.refreshAccessToken(tokenEndpoint, session.refreshToken, [
				"openid",
				"profile",
				"email",
				"offline_access",
			]);
			const newClaims = parseTokenClaims(newTokens.idToken());
			updateSession(sessionId, {
				accessToken: newTokens.accessToken(),
				refreshToken: newTokens.hasRefreshToken() ? newTokens.refreshToken() : session.refreshToken,
				idToken: newTokens.idToken(),
				tokenExpiry: newTokens.accessTokenExpiresAt(),
				customerId: newClaims.customer_id ?? null,
			});
		} catch {
			// Best effort — next login will pick up fresh claims
		}

		redirect(302, "/");
	},
};
