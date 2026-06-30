<script lang="ts">
	import { enhance } from "$app/forms";
	import type { ActionData } from "./$types";
	import { FIAT_CURRENCIES } from "$lib/currencies";
	import { Button } from "$lib/components/ui/button/index.js";
	import { Input } from "$lib/components/ui/input/index.js";
	import { Label } from "$lib/components/ui/label/index.js";
	import * as Select from "$lib/components/ui/select/index.js";

	let { form }: { form: ActionData } = $props();

	let baseCurrency = $state("USD");
	let isSubmitting = $state(false);
</script>

<div class="max-w-sm">
	<h1 class="text-2xl font-semibold mb-1">Create workspace</h1>
	<p class="text-sm text-muted-foreground mb-6">
		A workspace holds all the accounts and transactions for one financial context — e.g. personal, business, or a household.
	</p>

	<form
		method="POST"
		use:enhance={() => {
			isSubmitting = true;
			return async ({ update }) => {
				await update();
				isSubmitting = false;
			};
		}}
		class="flex flex-col gap-4"
	>
		<input type="hidden" name="baseCurrency" value={baseCurrency} />

		<div class="flex flex-col gap-1.5">
			<Label for="name">Name</Label>
			<Input
				id="name"
				name="name"
				placeholder="e.g. Personal, Business, Family"
				required
			/>
		</div>

		<div class="flex flex-col gap-1.5">
			<Label>Base currency</Label>
			<Select.Root
				type="single"
				value={baseCurrency}
				onValueChange={(v) => (baseCurrency = v)}
			>
				<Select.Trigger>
					{baseCurrency
						? `${baseCurrency} — ${FIAT_CURRENCIES.find((c) => c.code === baseCurrency)?.name ?? baseCurrency}`
						: "Select currency…"}
				</Select.Trigger>
				<Select.Content class="max-h-72 overflow-y-auto">
					{#each FIAT_CURRENCIES.filter((fc, i, arr) => arr.findIndex((x) => x.code === fc.code) === i) as fc (fc.code)}
						<Select.Item value={fc.code}>{fc.code} — {fc.name}</Select.Item>
					{/each}
				</Select.Content>
			</Select.Root>
			<p class="text-xs text-muted-foreground">
				Your primary reporting currency. You can add more currencies to accounts later.
			</p>
		</div>

		{#if form?.error}
			<p class="text-sm text-destructive">{form.error}</p>
		{/if}

		<Button type="submit" class="self-start" disabled={isSubmitting}>
			{isSubmitting ? "Creating…" : "Create workspace"}
		</Button>
	</form>
</div>
