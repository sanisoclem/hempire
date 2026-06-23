<script lang="ts">
	import type { Snippet } from 'svelte';

	let { children }: { children: Snippet } = $props();
</script>

<nav>
	<a href="/">Dashboard</a>
	<a href="/crm">CRM</a>
	<a href="/ledger">Ledger</a>
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
