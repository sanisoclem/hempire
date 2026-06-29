import { OAuth2Client, CodeChallengeMethod, generateState, generateCodeVerifier, decodeIdToken } from "arctic";
import { error } from "@sveltejs/kit";
import type { Cookies } from "@sveltejs/kit";
import { requireEnv } from "$lib/server/env";

const SCOPES = ["openid", "profile", "email", "offline_access", "urn:zitadel:iam:user:metadata"];
const STATE_COOKIE = "oauth_state";
const VERIFIER_COOKIE = "pkce_verifier";
const PKCE_COOKIE_OPTIONS = {
	httpOnly: true,
	secure: process.env.NODE_ENV === "production",
	sameSite: "lax" as const,
	maxAge: 600,
	path: "/",
};

function getConfig() {
	const domain = requireEnv("BFF_ZITADEL_DOMAIN");
	return {
		authorizationEndpoint: `${domain}/oauth/v2/authorize`,
		tokenEndpoint: `${domain}/oauth/v2/token`,
		client: new OAuth2Client(
			requireEnv("BFF_CLIENT_ID"),
			process.env.BFF_CLIENT_SECRET ?? null,
			requireEnv("BFF_REDIRECT_URI"),
		),
	};
}

export interface UserClaims {
	sub: string;
	name?: string;
	customerId?: string;
}

export interface TokenData {
	accessToken: string;
	refreshToken: string;
	idToken: string;
	tokenExpiry: Date;
	claims: UserClaims;
}

function parseClaims(idToken: string): UserClaims {
	const raw = decodeIdToken(idToken) as Record<string, unknown>;
	const metadata = raw["urn:zitadel:iam:user:metadata"] as Record<string, string> | undefined;
	const encodedCustomerId = metadata?.["customer_id"];
	return {
		sub: raw.sub as string,
		name: typeof raw.name === "string" ? raw.name : undefined,
		customerId: encodedCustomerId
			? Buffer.from(encodedCustomerId, "base64").toString("utf-8")
			: undefined,
	};
}

function tokenData(tokens: Awaited<ReturnType<OAuth2Client["validateAuthorizationCode"]>>, fallbackRefreshToken?: string): TokenData {
	const idToken = tokens.idToken();
	return {
		accessToken: tokens.accessToken(),
		refreshToken: tokens.hasRefreshToken() ? tokens.refreshToken() : (fallbackRefreshToken ?? ""),
		idToken,
		tokenExpiry: tokens.accessTokenExpiresAt(),
		claims: parseClaims(idToken),
	};
}

export function createAuthorizationUrl(cookies: Cookies): URL {
	const { authorizationEndpoint, client } = getConfig();
	const state = generateState();
	const codeVerifier = generateCodeVerifier();
	cookies.set(STATE_COOKIE, state, PKCE_COOKIE_OPTIONS);
	cookies.set(VERIFIER_COOKIE, codeVerifier, PKCE_COOKIE_OPTIONS);
	return client.createAuthorizationURLWithPKCE(
		authorizationEndpoint,
		state,
		CodeChallengeMethod.S256,
		codeVerifier,
		SCOPES,
	);
}

export async function exchangeCode(requestUrl: URL, cookies: Cookies): Promise<TokenData> {
	const code = requestUrl.searchParams.get("code");
	const state = requestUrl.searchParams.get("state");
	const storedState = cookies.get(STATE_COOKIE);
	const codeVerifier = cookies.get(VERIFIER_COOKIE);

	if (!code || !state || !storedState || !codeVerifier) error(400, "Missing OAuth parameters");
	if (state !== storedState) error(400, "State mismatch");

	cookies.delete(STATE_COOKIE, { path: "/" });
	cookies.delete(VERIFIER_COOKIE, { path: "/" });

	const { tokenEndpoint, client } = getConfig();
	const tokens = await client.validateAuthorizationCode(tokenEndpoint, code, codeVerifier);
	return tokenData(tokens);
}

export async function refreshTokens(refreshToken: string): Promise<TokenData> {
	const { tokenEndpoint, client } = getConfig();
	const tokens = await client.refreshAccessToken(tokenEndpoint, refreshToken, SCOPES);
	return tokenData(tokens, refreshToken);
}
