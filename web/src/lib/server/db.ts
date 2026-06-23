import postgres from "postgres";

const sql = postgres(
  process.env.DATABASE_URL ??
    "postgres://hempire:hempire@localhost:5432/hempire_bff",
);

export async function ensureSchema(): Promise<void> {
  await sql`
		CREATE TABLE IF NOT EXISTS operations (
			id            UUID        PRIMARY KEY,
			type          TEXT        NOT NULL,
			payload       JSONB       NOT NULL DEFAULT '{}',
			status        TEXT        NOT NULL DEFAULT 'optimistic',
			created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			confirmed_at  TIMESTAMPTZ
		)
	`;
}

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
