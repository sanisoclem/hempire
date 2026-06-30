<script lang="ts">
	import { ROUTES } from "$lib/routes";
	import { Badge } from "$lib/components/ui/badge/index.js";

	let { params }: { params: { workspaceId: string } } = $props();
	const workspaceId = $derived(params.workspaceId);
</script>

<div class="max-w-xl">
	<div class="flex items-center gap-3 mb-4">
		<h1 class="text-2xl font-semibold">Observe</h1>
		<Badge variant="secondary">Coming soon</Badge>
	</div>

	<p class="text-muted-foreground mb-6">
		Observe is the second step of the loop. After syncing your accounts and transactions,
		this view compares your <strong>actual financial reality</strong> against the
		<strong>systems and predictions</strong> you've set up in Adjust. Deviations are surfaced
		here — over- or under-spending, unexpected income, or accounts drifting from plan.
	</p>

	<p class="text-muted-foreground mb-6">
		Use Observe regularly (weekly or monthly) to stay aware of how your money is actually
		moving. The insight you gain here informs what to adjust in your systems, and
		ultimately whether your long-term goals in Strategize remain on track.
	</p>

	<div class="rounded-lg border border-dashed p-6 text-sm text-muted-foreground">
		Start by syncing your accounts: <a
			href={ROUTES.workspace.sync(workspaceId)}
			class="underline text-foreground">Go to Sync →</a
		>
	</div>
</div>
