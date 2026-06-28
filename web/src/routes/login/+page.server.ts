import { redirect } from "@sveltejs/kit";
import { generateState, generateCodeVerifier, CodeChallengeMethod, client, authorizationEndpoint } from "$lib/server/auth";
import type { Actions } from "./$types";

export const actions: Actions = {
	default: async ({ cookies }) => {
		const state = generateState();
		const codeVerifier = generateCodeVerifier();

		const url = client.createAuthorizationURLWithPKCE(
			authorizationEndpoint,
			state,
			CodeChallengeMethod.S256,
			codeVerifier,
			["openid", "profile", "email", "offline_access"],
		);

		const pkceOptions = {
			httpOnly: true,
			secure: process.env.NODE_ENV === "production",
			sameSite: "lax" as const,
			maxAge: 600,
			path: "/",
		};

		cookies.set("oauth_state", state, pkceOptions);
		cookies.set("pkce_verifier", codeVerifier, pkceOptions);

		redirect(302, url.toString());
	},
};
