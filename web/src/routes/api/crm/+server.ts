import { writeOptimistic } from "$lib/server/db";
import { error, json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

const CRM_API_URL = process.env.CRM_API_URL ?? "http://localhost:8080";

export const POST: RequestHandler = async ({ request }) => {
  const body = await request.json();
  const correlationId = crypto.randomUUID();
  const cmd = { ...body, correlationId };

  const res = await fetch(`${CRM_API_URL}/contacts`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(cmd),
  });

  if (!res.ok) error(502, "crm-api error");

  const data = await res.json();
  await writeOptimistic(correlationId, "CreateContact", data);

  return json({ ...data, _status: "optimistic", correlationId });
};
