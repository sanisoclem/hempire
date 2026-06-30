import '$lib/server/otel';
import { telemetryHandle } from '$lib/server/otel';
import { sequence } from '@sveltejs/kit/hooks';
import { redirect } from "@sveltejs/kit";
import { getSessionFromCookies, updateSession } from "$lib/server/session";
import { startKafkaConsumer } from "$lib/server/kafka";
import { refreshTokens } from "$lib/server/zitadel";
import { ROUTES } from "$lib/routes";
import type { Handle } from "@sveltejs/kit";

startKafkaConsumer().catch((err) => console.error("[kafka] consumer failed to start:", err));

const TOKEN_REFRESH_THRESHOLD_MS = 60_000;

const authHandle: Handle = async ({ event, resolve }) => {
  if (event.url.pathname.startsWith(ROUTES.login) || event.url.pathname === '/health') {
    return resolve(event);
  }

  const result = getSessionFromCookies(event.cookies);
  if (!result) redirect(302, ROUTES.login);

  let { session } = result;

  const expiresInMs = session.tokenExpiry.getTime() - Date.now();
  if (expiresInMs < TOKEN_REFRESH_THRESHOLD_MS) {
    const newTokens = await refreshTokens(session.refreshToken).catch(() => null);
    if (newTokens) {
      const patch = {
        accessToken: newTokens.accessToken,
        refreshToken: newTokens.refreshToken,
        idToken: newTokens.idToken,
        tokenExpiry: newTokens.tokenExpiry,
        customerId: newTokens.claims.customerId ?? session.customerId,
      };
      updateSession(result.sessionId, patch);
      session = { ...session, ...patch };
    }
  }

  event.locals.user = {
    userId: session.userId,
    userName: session.userName,
    customerId: session.customerId,
  };

  return resolve(event);
};

export const handle = sequence(telemetryHandle, authHandle);
