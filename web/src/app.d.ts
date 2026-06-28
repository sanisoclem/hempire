declare global {
	namespace App {
		interface Locals {
			user: { userId: string; customerId: string | null } | null;
		}
	}
}

export {};
