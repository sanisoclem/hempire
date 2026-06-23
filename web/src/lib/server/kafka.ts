import { Kafka } from "kafkajs";
import { confirmOperation, markTimedOut } from "./db";
import { broadcast } from "./sse";

const kafka = new Kafka({
  clientId: "hempire-bff",
  brokers: (process.env.KAFKA_BROKERS ?? "localhost:9092").split(","),
});

const consumer = kafka.consumer({ groupId: "bff" });

export async function startKafkaConsumer(): Promise<void> {
  await consumer.connect();
  await consumer.subscribe({
    topics: ["crm.events", "ledger.events"],
    fromBeginning: false,
  });

  await consumer.run({
    eachMessage: async ({ message }) => {
      if (!message.value) return;

      let event: Record<string, unknown>;
      try {
        event = JSON.parse(message.value.toString());
      } catch {
        console.error("BFF Kafka: failed to parse message");
        return;
      }

      const correlationId =
        (event["ccEvtCorrelationId"] as string | undefined) ??
        (event["cuEvtCorrelationId"] as string | undefined) ??
        (event["epEvtCorrelationId"] as string | undefined);

      if (!correlationId) {
        console.warn("BFF Kafka: event missing correlationId", event);
        return;
      }

      await confirmOperation(correlationId);
      broadcast({
        type: "confirmed",
        correlationId,
        operationType: detectType(event),
      });
    },
  });
}

function detectType(event: Record<string, unknown>): string {
  if ("ccEvtId" in event) return "ContactCreated";
  if ("cuEvtId" in event) return "ContactUpdated";
  if ("epEvtId" in event) return "EntryPosted";
  return "Unknown";
}

// Scan for optimistic rows that were never confirmed.
export function startTimeoutScanner(): void {
  setInterval(async () => {
    const timedOutIds = await markTimedOut();
    for (const id of timedOutIds) {
      broadcast({
        type: "timed_out",
        correlationId: id,
        operationType: "Unknown",
      });
    }
  }, 30_000);
}
