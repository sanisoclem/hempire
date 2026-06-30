import { browser } from "$app/environment";
import { BFF_PUBLIC_ORIGIN } from "$env/static/public";
import { electricCollectionOptions } from "@tanstack/electric-db-collection";
import { localOnlyCollectionOptions } from "@tanstack/db";
import { createCollection } from "@tanstack/svelte-db";

export interface UserRow {
  [key: string]: unknown;
  customer_id: string;
  friendly_name: string;
  identity_id: string;
  expiry: string | null;
  request_id: string | null;
}

export const usersCollection = browser
  ? createCollection(
      electricCollectionOptions<UserRow>({
        id: "users",
        shapeOptions: { url: `${BFF_PUBLIC_ORIGIN}/api/shapes/users` },
        getKey: (row) => row.customer_id,
      }),
    )
  : createCollection(
      localOnlyCollectionOptions<UserRow>({
        id: "users",
        getKey: (row) => row.customer_id,
      }),
    );
