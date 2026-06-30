import { redirect } from "@sveltejs/kit";
import { startKafkaConsumer, startTimeoutScanner } from "$lib/server/kafka";
import { getSessionFromCookies } from "$lib/server/session";
import { ROUTES } from "$lib/routes";
import type { Handle } from "@sveltejs/kit";

startKafkaConsumer()
	.then(() => startTimeoutScanner())
	.catch((err) => console.error("BFF startup error:", err));

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
