import postgres from "postgres";

if (!process.env.BFF_DATABASE_URL) {
  throw new Error("BFF_DATABASE_URL is required");
}

const sql = postgres(process.env.BFF_DATABASE_URL);

export async function writeOptimistic(
  id: string,
  type: string,
  payload: unknown,
): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  await sql`
		INSERT INTO operations (id, type, payload)
		VALUES (${id}, ${type}, ${sql.json(payload as any)})
	`;
}

export async function confirmOperation(correlationId: string): Promise<void> {
  await sql`
		UPDATE operations
		SET status = 'committed', confirmed_at = NOW()
		WHERE id = ${correlationId} AND status = 'optimistic'
	`;
}

export async function markTimedOut(): Promise<string[]> {
  const rows = await sql<{ id: string }[]>`
		UPDATE operations
		SET status = 'timed_out'
		WHERE status = 'optimistic' AND created_at < NOW() - INTERVAL '30 seconds'
		RETURNING id
	`;
  return rows.map((r) => r.id);
}

export default sql;
