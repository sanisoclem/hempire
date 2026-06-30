import '$lib/server/otel';
import { telemetryHandle } from '$lib/server/otel';
import { sequence } from '@sveltejs/kit/hooks';
import { redirect } from "@sveltejs/kit";
import { getSessionFromCookies } from "$lib/server/session";
import { startKafkaConsumer } from "$lib/server/kafka";
import { ROUTES } from "$lib/routes";
import type { Handle } from "@sveltejs/kit";

startKafkaConsumer().catch((err) => console.error("[kafka] consumer failed to start:", err));

const authHandle: Handle = async ({ event, resolve }) => {
  if (event.url.pathname.startsWith(ROUTES.login)) return resolve(event);

  const result = getSessionFromCookies(event.cookies);
  if (!result) redirect(302, ROUTES.login);

  event.locals.user = {
    userId: result.session.userId,
    userName: result.session.userName,
    customerId: result.session.customerId,
  };

  return resolve(event);
};

export const handle = sequence(telemetryHandle, authHandle);
