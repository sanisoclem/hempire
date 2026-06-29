import { redirect } from "@sveltejs/kit";
import type { Cookies } from "@sveltejs/kit";
import { getSessionFromCookies } from "$lib/server/session";

export interface AuthContext {
  accessToken: string;
  refreshToken: string;
  sessionId: string;
  userName: string | null;
}

export interface OnboardedContext extends AuthContext {
  customerId: string;
}

export function requireAuthenticated(cookies: Cookies): AuthContext {
  const result = getSessionFromCookies(cookies);
  if (!result) redirect(302, "/login");
  const { session, sessionId } = result;
  return {
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    sessionId,
    userName: session.userName,
  };
}

export function requireOnboarded(cookies: Cookies): OnboardedContext {
  const result = getSessionFromCookies(cookies);
  if (!result) redirect(302, "/login");
  const { session, sessionId } = result;
  console.log(session.accessToken);
  if (!session.customerId) redirect(302, "/onboarding");
  return {
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    sessionId,
    userName: session.userName,
    customerId: session.customerId,
  };
}
