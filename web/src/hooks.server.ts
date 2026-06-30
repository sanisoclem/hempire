import { redirect } from "@sveltejs/kit";
import { getSessionFromCookies } from "$lib/server/session";
import { ROUTES } from "$lib/routes";
import type { Handle } from "@sveltejs/kit";

export const handle: Handle = async ({ event, resolve }) => {
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
