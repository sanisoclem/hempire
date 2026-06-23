import { ensureSchema } from "$lib/server/db";
import { startKafkaConsumer, startTimeoutScanner } from "$lib/server/kafka";

// Runs once on server startup — initialise DB schema, start Kafka consumer and timeout scanner.
ensureSchema()
  .then(() => startKafkaConsumer())
  .then(() => startTimeoutScanner())
  .catch((err) => console.error("BFF startup error:", err));

export const handle = async ({ event, resolve }) => resolve(event);
