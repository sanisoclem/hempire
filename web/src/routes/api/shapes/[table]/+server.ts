import { error } from "@sveltejs/kit";
import { requireAuthenticated } from "$lib/server/guards";
import { requireEnv } from "$lib/server/env";
import type { RequestHandler } from "./$types";

const ALLOWED_TABLES = ["users"] as const;
type AllowedTable = (typeof ALLOWED_TABLES)[number];

export const GET: RequestHandler = async ({ cookies, url, params }) => {
  const { customerId } = requireAuthenticated(cookies);
  if (!customerId) throw error(403, "Not onboarded");

  const table = params.table;
  if (!(ALLOWED_TABLES as readonly string[]).includes(table)) throw error(404, "Unknown table");

  const electricUrl = requireEnv("BFF_ELECTRIC_URL");
  const target = new URL(`${electricUrl}/v1/shape`);

  for (const [k, v] of url.searchParams) target.searchParams.set(k, v);

  // Enforce table and customer isolation — always overwrite any client-supplied values
  target.searchParams.set("table", table as AllowedTable);
  target.searchParams.set("where", `"customer_id" = '${customerId}'`);

  const upstream = await fetch(target);
  const headers = new Headers(upstream.headers);
  headers.delete("content-encoding");
  headers.delete("content-length");
  return new Response(upstream.body, { status: upstream.status, headers });
};
