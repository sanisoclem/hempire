// Mirror of Haskell *-public types. Keep in sync with CRM.Types and Ledger.Types.

export type OperationStatus = "optimistic" | "committed" | "timed_out";

export interface Operation {
  id: string;
  type: string;
  payload: unknown;
  status: OperationStatus;
  createdAt: string;
  confirmedAt: string | null;
}

// CRM
export interface ContactId {
  tag: "ContactId";
  value: string;
}
export interface CreateContact {
  name: string;
  email: string;
  correlationId: string;
}
export type CrmResponse<A> =
  | { tag: "Ok"; value: A }
  | { tag: "Err"; value: CrmError };
export type CrmError =
  | { tag: "NotFound"; value: string }
  | { tag: "ValidationFailed"; value: string[] }
  | { tag: "Conflict"; value: string };

// Ledger
export interface EntryId {
  tag: "EntryId";
  value: string;
}
export interface PostEntry {
  debit: string;
  credit: string;
  amount: number; // cents
  description: string;
  correlationId: string;
}

// SSE event envelope sent from BFF to browser
export interface SseEvent {
  type: "confirmed" | "timed_out";
  correlationId: string;
  operationType: string;
}
