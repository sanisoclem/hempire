import { writeOptimistic } from "$lib/server/db";
import { error, json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

const LEDGER_API_URL = process.env.LEDGER_API_URL ?? "http://localhost:8081";

export const POST: RequestHandler = async ({ request }) => {
  const body = await request.json();
  const correlationId = crypto.randomUUID();
  const cmd = { ...body, correlationId };

  const res = await fetch(`${LEDGER_API_URL}/entries`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(cmd),
  });

  if (!res.ok) error(502, "ledger-api error");

  const data = await res.json();
  await writeOptimistic(correlationId, "PostEntry", data);

  return json({ ...data, _status: "optimistic", correlationId });
};
