import { SpanKind, SpanStatusCode, context, propagation, trace } from "@opentelemetry/api";
import { Kafka } from "kafkajs";
import { config } from "$lib/server/config";
import { upsertBffUserConfirmed } from "./db";

const tracer = trace.getTracer("hempire-bff");

export async function startKafkaConsumer(): Promise<void> {
	const kafka = new Kafka({
		clientId: "hempire-bff",
		brokers: config.kafka.brokers,
	});
	const consumer = kafka.consumer({ groupId: "bff" });
	await consumer.connect();
	await consumer.subscribe({ topics: ["crm.events"], fromBeginning: false });
	await consumer.run({
		eachMessage: async ({ topic, partition, message }) => {
			if (!message.value) return;

			const headers: Record<string, string> = {};
			if (message.headers) {
				for (const [key, val] of Object.entries(message.headers)) {
					if (val !== undefined) headers[key] = val.toString();
				}
			}
			const parentCtx = propagation.extract(context.active(), headers);

			await context.with(parentCtx, () =>
				tracer.startActiveSpan(
					`${topic} process`,
					{ kind: SpanKind.CONSUMER, attributes: { "messaging.system": "kafka", "messaging.destination": topic, "messaging.kafka.partition": partition } },
					async (span) => {
						try {
							let event: Record<string, unknown>;
							try {
								event = JSON.parse(message.value!.toString());
							} catch {
								console.error("BFF Kafka: failed to parse message");
								span.setStatus({ code: SpanStatusCode.ERROR, message: "parse error" });
								return;
							}
							if (topic === "crm.events") await handleCrmEvent(event);
							span.setStatus({ code: SpanStatusCode.OK });
						} catch (err) {
							span.recordException(err as Error);
							span.setStatus({ code: SpanStatusCode.ERROR });
							throw err;
						} finally {
							span.end();
						}
					}
				)
			);
		},
	});
}

async function handleCrmEvent(event: Record<string, unknown>): Promise<void> {
	if (isCustomerOnboarded(event)) {
		await upsertBffUserConfirmed({
			customerId: event.customerId,
			friendlyName: event.friendlyName,
			identityId: event.identityId,
			requestId: event.inviteId,
		});
	}
}

function isCustomerOnboarded(
	event: Record<string, unknown>,
): event is { customerId: string; inviteId: string; friendlyName: string; identityId: string; at: string } {
	return (
		typeof event.customerId === "string" &&
		typeof event.inviteId === "string" &&
		typeof event.friendlyName === "string" &&
		typeof event.identityId === "string" &&
		typeof event.at === "string"
	);
}
