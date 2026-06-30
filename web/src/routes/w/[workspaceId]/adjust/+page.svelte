<script lang="ts">
	import { ROUTES } from "$lib/routes";
	import { Badge } from "$lib/components/ui/badge/index.js";

	let { params }: { params: { workspaceId: string } } = $props();
	const workspaceId = $derived(params.workspaceId);
</script>

<div class="max-w-xl">
	<div class="flex items-center gap-3 mb-4">
		<h1 class="text-2xl font-semibold">Adjust</h1>
		<Badge variant="secondary">Coming soon</Badge>
	</div>

	<p class="text-muted-foreground mb-6">
		Adjust is where you build and refine the <strong>systems that model your financial future</strong>.
		You define rules and recurring predictions — for example, a salary arriving on the 15th
		of each month, or a rent payment every first. These predictions form an <em>overlay ledger</em>
		that sits on top of your actual transaction history.
	</p>

	<p class="text-muted-foreground mb-6">
		The overlay ledger is always expressed as an <strong>offset from reality</strong>: a zero
		balance means predictions matched actuals perfectly. A positive offset means you received
		more than expected; negative means less. Over time, the accuracy of your predictions
		measures your <em>predicting power</em> — which feeds directly into how achievable
		your goals in Strategize are.
	</p>

	<p class="text-muted-foreground mb-6">
		Planned features include: recurring transaction rules, scenario modeling,
		cadence-based income/expense templates, and goal contribution tracking.
	</p>

	<div class="rounded-lg border border-dashed p-6 text-sm text-muted-foreground">
		First, get your accounts in order: <a
			href={ROUTES.workspace.sync(workspaceId)}
			class="underline text-foreground">Go to Sync →</a
		>
	</div>
</div>
