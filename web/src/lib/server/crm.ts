import { config } from "$lib/server/config";

export class CrmError extends Error {
	constructor(
		public readonly status: number,
		public readonly clientMessage: string,
	) {
		super(clientMessage);
		this.name = "CrmError";
	}
}

function clientMessage(status: number): string {
	const messages: Record<number, string> = {
		401: "Unauthorized",
		403: "Forbidden",
		404: "Not found",
		409: "Conflict",
		422: "Invalid request",
	};
	return messages[status] ?? "Request failed";
}

async function request(method: string, path: string, accessToken: string, body?: unknown): Promise<Response> {
	let res: Response;
	try {
		res = await fetch(`${config.crm.apiUrl}${path}`, {
			method,
			headers: {
				"Content-Type": "application/json",
				Authorization: `Bearer ${accessToken}`,
			},
			body: body !== undefined ? JSON.stringify(body) : undefined,
		});
	} catch (err) {
		console.error(`[crm] ${method} ${path} → network error:`, err);
		throw new CrmError(502, "Could not reach service");
	}

	if (!res.ok) {
		const raw = await res.text().catch(() => "<unreadable>");
		if (res.status === 400) {
			console.error(`[crm] BUG: ${method} ${path} → 400\n${raw}`);
			throw new CrmError(500, "Internal error");
		} else if (res.status >= 500) {
			console.error(`[crm] ${method} ${path} → ${res.status}\n${raw}`);
			throw new CrmError(502, "Service unavailable");
		} else {
			console.warn(`[crm] ${method} ${path} → ${res.status}\n${raw}`);
			throw new CrmError(res.status, clientMessage(res.status));
		}
	}

	return res;
}

async function call(method: string, path: string, accessToken: string, body?: unknown): Promise<void> {
	await request(method, path, accessToken, body);
}

async function callJson<T>(method: string, path: string, accessToken: string, body?: unknown): Promise<T> {
	const res = await request(method, path, accessToken, body);
	return res.json() as Promise<T>;
}

export interface OnboardResult {
	customerId: string;
	friendlyName: string;
	identityId: string;
}

export async function onboard(accessToken: string, inviteId: string): Promise<OnboardResult> {
	return callJson<OnboardResult>("POST", "/onboarding", accessToken, { inviteId });
}
