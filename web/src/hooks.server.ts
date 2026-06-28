import { redirect } from "@sveltejs/kit";
import { startKafkaConsumer, startTimeoutScanner } from "$lib/server/kafka";
import { verifyAndExtractSessionId, getSession, SESSION_COOKIE_NAME } from "$lib/server/session";
import type { Handle } from "@sveltejs/kit";

startKafkaConsumer()
	.then(() => startTimeoutScanner())
	.catch((err) => console.error("BFF startup error:", err));

export const handle: Handle = async ({ event, resolve }) => {
	if (event.url.pathname.startsWith("/login")) {
		return resolve(event);
	}

	const cookieValue = event.cookies.get(SESSION_COOKIE_NAME);
	if (cookieValue) {
		const sessionId = verifyAndExtractSessionId(cookieValue);
		if (sessionId) {
			const session = getSession(sessionId);
			if (session) {
				event.locals.user = {
					userId: session.userId,
					customerId: session.customerId,
				};
				return resolve(event);
			}
		}
	}

	event.locals.user = null;
	redirect(302, "/login");
};
