<script lang="ts">
	import { ROUTES } from "$lib/routes";
	import { Badge } from "$lib/components/ui/badge/index.js";

	let { params }: { params: { workspaceId: string } } = $props();
	const workspaceId = $derived(params.workspaceId);
</script>

<div class="max-w-xl">
	<div class="flex items-center gap-3 mb-4">
		<h1 class="text-2xl font-semibold">Strategize</h1>
		<Badge variant="secondary">Coming soon</Badge>
	</div>

	<p class="text-muted-foreground mb-6">
		Strategize is where you define your <strong>long-term financial goals</strong>.
		Unlike the weekly Sync–Observe–Adjust loop, Strategize is done infrequently —
		typically once when you start, then reviewed quarterly or annually.
	</p>

	<p class="text-muted-foreground mb-6">
		Each goal is described as precisely as possible: what you want to achieve,
		by when, and how much it will require. The date is important — vague goals
		are hard to measure. Example: <em>"Save $50,000 for a house down payment
		by December 2027."</em>
	</p>

	<p class="text-muted-foreground mb-6">
		Your predicting power (measured in Adjust) feeds into whether these goals are
		realistically achievable on the current trajectory. If predictions consistently
		miss, you either adjust your systems or revisit the goal timeline.
	</p>

	<p class="text-muted-foreground mb-6">
		Planned features: goal creation with target amount and date, goal progress
		visualization, trajectory modeling based on current savings rate, and
		alerts when your trajectory diverges from the goal.
	</p>

	<div class="rounded-lg border border-dashed p-6 text-sm text-muted-foreground">
		Start by syncing your accounts: <a
			href={ROUTES.workspace.sync(workspaceId)}
			class="underline text-foreground">Go to Sync →</a
		>
	</div>
</div>
