import { redirect, error } from "@sveltejs/kit";
import { client, tokenEndpoint, parseTokenClaims } from "$lib/server/auth";
import {
	createSession,
	generateSessionId,
	signSessionId,
	SESSION_COOKIE_NAME,
	SESSION_COOKIE_OPTIONS,
} from "$lib/server/session";
import type { RequestHandler } from "./$types";

export const GET: RequestHandler = async ({ url, cookies }) => {
	const code = url.searchParams.get("code");
	const state = url.searchParams.get("state");
	const storedState = cookies.get("oauth_state");
	const codeVerifier = cookies.get("pkce_verifier");

	if (!code || !state || !storedState || !codeVerifier) {
		error(400, "Missing OAuth parameters");
	}
	if (state !== storedState) {
		error(400, "State mismatch — possible CSRF");
	}

	let tokens;
	try {
		tokens = await client.validateAuthorizationCode(tokenEndpoint, code, codeVerifier);
	} catch {
		error(400, "Token exchange failed");
	}

	cookies.delete("oauth_state", { path: "/" });
	cookies.delete("pkce_verifier", { path: "/" });

	const claims = parseTokenClaims(tokens.idToken());
	const sessionId = generateSessionId();

	createSession({
		sessionId,
		userId: claims.sub,
		customerId: claims.customer_id ?? null,
		accessToken: tokens.accessToken(),
		refreshToken: tokens.hasRefreshToken() ? tokens.refreshToken() : "",
		idToken: tokens.idToken(),
		tokenExpiry: tokens.accessTokenExpiresAt(),
	});

	cookies.set(SESSION_COOKIE_NAME, signSessionId(sessionId), {
		...SESSION_COOKIE_OPTIONS,
		secure: process.env.NODE_ENV === "production",
	});

	if (claims.customer_id) {
		redirect(302, "/");
	} else {
		redirect(302, "/onboarding");
	}
};
