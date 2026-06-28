import { writeOptimistic } from "$lib/server/db";
import { error, json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

export const POST: RequestHandler = async ({ request }) => {
  const ledgerApiUrl = process.env.BFF_LEDGER_API_URL;
  if (!ledgerApiUrl) error(503, "BFF_LEDGER_API_URL is not configured");

  const body = await request.json();
  const correlationId = crypto.randomUUID();
  const cmd = { ...body, correlationId };

  const res = await fetch(`${ledgerApiUrl}/entries`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(cmd),
  });

  if (!res.ok) error(502, "ledger-api error");

  const data = await res.json();
  await writeOptimistic(correlationId, "PostEntry", data);

  return json({ ...data, _status: "optimistic", correlationId });
};
