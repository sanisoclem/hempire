import type { Ledger } from "$lib/types";

const store = new Map<string, Ledger>();

export function getLedgers(): Ledger[] {
  return [...store.values()];
}

export function createLedger(name: string, baseCurrency: string): Ledger {
  const ledger: Ledger = { id: crypto.randomUUID(), name, baseCurrency };
  store.set(ledger.id, ledger);
  return ledger;
}

export function getLedgerById(id: string): Ledger | undefined {
  return store.get(id);
}
