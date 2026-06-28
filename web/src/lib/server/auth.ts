import { OAuth2Client, CodeChallengeMethod, decodeIdToken } from "arctic";

export { generateState, generateCodeVerifier, CodeChallengeMethod } from "arctic";

function requireEnv(key: string): string {
	const val = process.env[key];
	if (!val) throw new Error(`${key} is required`);
	return val;
}

const domain = requireEnv("BFF_ZITADEL_DOMAIN");

export const authorizationEndpoint = `${domain}/oauth/v2/authorize`;
export const tokenEndpoint = `${domain}/oauth/v2/token`;

export const client = new OAuth2Client(
	requireEnv("BFF_CLIENT_ID"),
	process.env.BFF_CLIENT_SECRET || null,
	requireEnv("BFF_REDIRECT_URI"),
);

export interface ZitadelClaims {
	sub: string;
	customer_id?: string;
}

export function parseTokenClaims(idToken: string): ZitadelClaims {
	return decodeIdToken(idToken) as ZitadelClaims;
}
