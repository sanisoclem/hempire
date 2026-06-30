import { SpanKind, SpanStatusCode, context, propagation, trace } from "@opentelemetry/api";
import { Kafka, type Consumer } from "kafkajs";
import { config } from "$lib/server/config";
import { upsertBffUserConfirmed } from "./db";
import { CRM_EVENTS_TOPIC, CrmEventSchema, type CrmEvent } from "./events";

const tracer = trace.getTracer("hempire-bff");

let _consumer: Consumer | null = null;

export async function startKafkaConsumer(): Promise<void> {
	const kafka = new Kafka({
		clientId: "hempire-bff",
		brokers: config.kafka.brokers,
	});
	const consumer = kafka.consumer({ groupId: "bff" });
	_consumer = consumer;
	await consumer.connect();
	await consumer.subscribe({ topics: [CRM_EVENTS_TOPIC], fromBeginning: true });
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
							const parsed = CrmEventSchema.safeParse(
								JSON.parse(message.value!.toString()),
							);
							if (!parsed.success) {
								console.error("BFF Kafka: unrecognised event shape", parsed.error.issues);
								span.setStatus({ code: SpanStatusCode.ERROR, message: "schema validation failed" });
								return;
							}
							await handleCrmEvent(parsed.data);
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

export async function stopKafkaConsumer(): Promise<void> {
	if (_consumer) {
		await _consumer.disconnect();
		_consumer = null;
	}
}

async function handleCrmEvent(event: CrmEvent): Promise<void> {
	if (event.eventType === "CustomerOnboarded") {
		await upsertBffUserConfirmed({
			customerId: event.customerId,
			friendlyName: event.friendlyName,
			identityId: event.identityId,
			requestId: event.inviteId,
		});
	}
}
