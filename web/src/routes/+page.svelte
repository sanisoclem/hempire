<script lang="ts">
	import type { SseEvent } from '$lib/types';
	import { onMount } from 'svelte';

	let events: SseEvent[] = $state([]);

	onMount(() => {
		const source = new EventSource('/events');

		source.onmessage = (e: MessageEvent) => {
			const event = JSON.parse(e.data) as SseEvent;
			events = [event, ...events].slice(0, 50);
		};

		source.onerror = () => {
			console.warn('SSE connection lost, retrying...');
		};

		return () => source.close();
	});
</script>

<main>
	<h1>Hempire</h1>
	<p>Welcome. Use the navigation above to access CRM and Ledger.</p>

	{#if events.length > 0}
		<section>
			<h2>Recent activity</h2>
			<ul>
				{#each events as event (event.correlationId + event.type)}
					<li>
						<span class="status {event.type}">{event.type}</span>
						{event.operationType} — <code>{event.correlationId}</code>
					</li>
				{/each}
			</ul>
		</section>
	{/if}
</main>

<style>
	main { padding: 2rem; }
	ul   { list-style: none; padding: 0; }
	li   { padding: 0.4rem 0; border-bottom: 1px solid #f3f4f6; }
	.status          { display: inline-block; padding: 0.1rem 0.4rem; border-radius: 4px; font-size: 0.75rem; margin-right: 0.5rem; }
	.status.confirmed  { background: #d1fae5; color: #065f46; }
	.status.timed_out  { background: #fee2e2; color: #991b1b; }
</style>
