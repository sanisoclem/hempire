import { error } from "@sveltejs/kit";
import { requireAuthenticated } from "$lib/server/guards";
import { config } from "$lib/server/config";
import type { RequestHandler } from "./$types";

const ALLOWED_TABLES = [
	"users",
	"workspaces",
	"workspace_currencies",
	"accounts",
	"journal_entries",
	"journal_entry_account_transactions",
	"balance_snapshots",
] as const;
type AllowedTable = (typeof ALLOWED_TABLES)[number];

export const GET: RequestHandler = async ({ cookies, url, params }) => {
  const { customerId } = requireAuthenticated(cookies);
  if (!customerId) throw error(403, "Not onboarded");

  const table = params.table;
  if (!(ALLOWED_TABLES as readonly string[]).includes(table)) throw error(404, "Unknown table");

  const electricUrl = config.electric.url;
  const target = new URL(`${electricUrl}/v1/shape`);

  const ELECTRIC_PARAMS = new Set(["offset", "cursor", "live", "columns", "handle"]);
  for (const [k, v] of url.searchParams) {
    if (ELECTRIC_PARAMS.has(k)) target.searchParams.set(k, v);
  }

  // Enforce table and customer isolation — always overwrite any client-supplied values
  if (!/^cust_[A-Za-z0-9]+$/.test(customerId)) throw error(500, "Invariant violated");
  target.searchParams.set("table", table as AllowedTable);
  target.searchParams.set("where", `"customer_id" = '${customerId}'`);

  const upstream = await fetch(target);
  const headers = new Headers(upstream.headers);
  headers.delete("content-encoding");
  headers.delete("content-length");
  return new Response(upstream.body, { status: upstream.status, headers });
};
