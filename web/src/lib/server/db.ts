import { SpanKind, SpanStatusCode, trace } from '@opentelemetry/api';
import postgres from 'postgres';
import { config } from '$lib/server/config';

const sql = postgres(config.database.url);

const tracer = trace.getTracer('hempire-bff');

export async function withDbSpan<T>(operation: string, fn: () => Promise<T>): Promise<T> {
	return tracer.startActiveSpan(
		operation,
		{ kind: SpanKind.CLIENT, attributes: { 'db.system': 'postgresql' } },
		async (span) => {
			try {
				return await fn();
			} catch (err) {
				span.recordException(err as Error);
				span.setStatus({ code: SpanStatusCode.ERROR });
				throw err;
			} finally {
				span.end();
			}
		}
	);
}

export interface BffUserParams {
	customerId: string;
	friendlyName: string;
	identityId: string;
	requestId: string;
}

export async function insertBffUserOptimistic(
	params: BffUserParams & { expiry: Date }
): Promise<void> {
	await withDbSpan('db.insert.users', () =>
		sql`INSERT INTO users (customer_id, friendly_name, identity_id, request_id, expiry) VALUES (${params.customerId}, ${params.friendlyName}, ${params.identityId}, ${params.requestId}, ${params.expiry}) ON CONFLICT (customer_id) DO NOTHING`
	);
}

export async function upsertBffUserConfirmed(params: BffUserParams): Promise<void> {
	await withDbSpan('db.upsert.users', () =>
		sql`INSERT INTO users (customer_id, friendly_name, identity_id, request_id, expiry) VALUES (${params.customerId}, ${params.friendlyName}, ${params.identityId}, ${params.requestId}, NULL) ON CONFLICT (customer_id) DO UPDATE SET friendly_name = EXCLUDED.friendly_name, identity_id = EXCLUDED.identity_id, request_id = EXCLUDED.request_id, expiry = NULL`
	);
}

export default sql;
