import { randomBytes, createHmac, timingSafeEqual } from "crypto";
import type { Cookies } from "@sveltejs/kit";
import { requireEnv } from "$lib/server/env";

export interface Session {
	sessionId: string;
	userId: string;
	userName: string | null;
	customerId: string | null;
	accessToken: string;
	refreshToken: string;
	idToken: string;
	tokenExpiry: Date;
}

const sessions = new Map<string, Session>();

function getSecretKey(): Buffer {
	return Buffer.from(requireEnv("BFF_SESSION_SECRET"), "hex");
}

export const SESSION_COOKIE_NAME = "hempire_session";

const SESSION_COOKIE_OPTIONS = {
	httpOnly: true,
	secure: process.env.NODE_ENV === "production",
	sameSite: "lax" as const,
	path: "/",
};

export function generateSessionId(): string {
	return randomBytes(20).toString("base64url");
}

export function signSessionId(sessionId: string): string {
	const mac = createHmac("sha256", getSecretKey()).update(sessionId).digest("base64url");
	return `${sessionId}.${mac}`;
}

export function verifyAndExtractSessionId(cookieValue: string): string | null {
	const dotIndex = cookieValue.lastIndexOf(".");
	if (dotIndex === -1) return null;
	const sessionId = cookieValue.slice(0, dotIndex);
	const receivedMac = cookieValue.slice(dotIndex + 1);
	const expected = createHmac("sha256", getSecretKey()).update(sessionId).digest();
	const received = Buffer.from(receivedMac, "base64url");
	if (expected.length !== received.length) return null;
	if (!timingSafeEqual(expected, received)) return null;
	return sessionId;
}

export function setSessionCookie(cookies: Cookies, sessionId: string): void {
	cookies.set(SESSION_COOKIE_NAME, signSessionId(sessionId), SESSION_COOKIE_OPTIONS);
}

export function getSessionFromCookies(cookies: Cookies): { session: Session; sessionId: string } | null {
	const cookieValue = cookies.get(SESSION_COOKIE_NAME);
	if (!cookieValue) return null;
	const sessionId = verifyAndExtractSessionId(cookieValue);
	if (!sessionId) return null;
	const session = sessions.get(sessionId);
	if (!session) return null;
	return { session, sessionId };
}

export function createSession(session: Session): void {
	sessions.set(session.sessionId, session);
}

export function getSession(sessionId: string): Session | undefined {
	return sessions.get(sessionId);
}

export function deleteSession(sessionId: string): void {
	sessions.delete(sessionId);
}

export function updateSession(
	sessionId: string,
	patch: Partial<Pick<Session, "customerId" | "accessToken" | "refreshToken" | "idToken" | "tokenExpiry">>,
): void {
	const session = sessions.get(sessionId);
	if (!session) return;
	sessions.set(sessionId, { ...session, ...patch });
}
