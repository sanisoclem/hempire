import { redirect, error } from "@sveltejs/kit";
import { exchangeCode } from "$lib/server/zitadel";
import { createSession, generateSessionId, setSessionCookie } from "$lib/server/session";
import { ROUTES } from "$lib/routes";
import type { RequestHandler } from "./$types";

export const GET: RequestHandler = async ({ url, cookies }) => {
	let tokenData;
	try {
		tokenData = await exchangeCode(url, cookies);
	} catch (err) {
		console.error("[login/callback] token exchange failed:", err);
		error(400, "Login failed");
	}

	const sessionId = generateSessionId();
	createSession({
		sessionId,
		userId: tokenData.claims.sub,
		userName: tokenData.claims.name ?? null,
		customerId: tokenData.claims.customerId ?? null,
		accessToken: tokenData.accessToken,
		refreshToken: tokenData.refreshToken,
		idToken: tokenData.idToken,
		tokenExpiry: tokenData.tokenExpiry,
	});
	setSessionCookie(cookies, sessionId);

	redirect(302, tokenData.claims.customerId ? ROUTES.home : ROUTES.onboarding);
};
