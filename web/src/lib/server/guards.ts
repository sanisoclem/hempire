import { redirect } from "@sveltejs/kit";
import type { Cookies } from "@sveltejs/kit";
import { getSessionFromCookies } from "$lib/server/session";
import { ROUTES } from "$lib/routes";

export interface AuthContext {
  accessToken: string;
  refreshToken: string;
  sessionId: string;
  userName: string | null;
  customerId: string | null;
}

export interface OnboardedContext extends AuthContext {
  customerId: string;
}

export function requireAuthenticated(cookies: Cookies): AuthContext {
  const result = getSessionFromCookies(cookies);
  if (!result) redirect(302, ROUTES.login);
  const { session, sessionId } = result;
  return {
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    sessionId,
    userName: session.userName,
    customerId: session.customerId,
  };
}

export function requireOnboarded(cookies: Cookies): OnboardedContext {
  const result = getSessionFromCookies(cookies);
  if (!result) redirect(302, ROUTES.login);
  const { session, sessionId } = result;
  if (!session.customerId) redirect(302, ROUTES.onboarding);
  return {
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    sessionId,
    userName: session.userName,
    customerId: session.customerId,
  };
}
