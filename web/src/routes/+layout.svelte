<script lang="ts">
	import type { Snippet } from 'svelte';
	import { ROUTES } from '$lib/routes';

	let { children }: { children: Snippet } = $props();
</script>

<nav>
	<a href={ROUTES.home}>Dashboard</a>
	<a href={ROUTES.crm}>CRM</a>
	<a href={ROUTES.ledger}>Ledger</a>
</nav>

{@render children()}

<style>
	nav {
		display: flex;
		gap: 1rem;
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
	}
</style>
