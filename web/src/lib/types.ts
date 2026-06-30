// Mirror of *-public types. Keep in sync with CRM.Types and Ledger.Types.

export type Ledger = { id: string; name: string; baseCurrency: string };

export type CrmResponse<A> =
  | { tag: "Ok"; value: A }
  | { tag: "Err"; value: CrmError };
export type CrmError =
  | { tag: "NotFound"; value: string }
  | { tag: "ValidationFailed"; value: string[] }
  | { tag: "Conflict"; value: string };

