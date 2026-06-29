declare global {
	namespace App {
		interface Locals {
			user: { userId: string; userName: string | null; customerId: string | null } | null;
		}
	}
}

export {};
