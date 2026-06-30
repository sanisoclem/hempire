import { ShapeStream, Shape } from "@electric-sql/client";

export interface UserRow {
	customer_id: string;
	friendly_name: string;
	identity_id: string;
	expiry: string | null;
	request_id: string | null;
}

export function createUserShape(): Shape<UserRow> {
	const stream = new ShapeStream<UserRow>({ url: `/api/shapes/users` });
	return new Shape(stream);
}
