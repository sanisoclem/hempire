import { Kafka } from "kafkajs";
import { requireEnv } from "$lib/server/env";
import { upsertBffUserConfirmed } from "./db";

const kafka = new Kafka({
	clientId: "hempire-bff",
	brokers: requireEnv("KAFKA_BROKERS").split(","),
});

const consumer = kafka.consumer({ groupId: "bff" });

export async function startKafkaConsumer(): Promise<void> {
	await consumer.connect();
	await consumer.subscribe({ topics: ["crm.events"], fromBeginning: false });
	await consumer.run({
		eachMessage: async ({ topic, message }) => {
			if (!message.value) return;
			let event: Record<string, unknown>;
			try {
				event = JSON.parse(message.value.toString());
			} catch {
				console.error("BFF Kafka: failed to parse message");
				return;
			}
			if (topic === "crm.events") await handleCrmEvent(event);
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
