<script lang="ts">
	import { enhance } from "$app/forms";
	import { ROUTES } from "$lib/routes";
	import type { PageData, ActionData } from "./$types";
	import type { Account, AccountType } from "$lib/domain";
	import { accountTypeLabel, formatBalance } from "$lib/domain";
	import { FIAT_CURRENCIES } from "$lib/currencies";
	import * as Table from "$lib/components/ui/table/index.js";
	import * as Sheet from "$lib/components/ui/sheet/index.js";
	import * as DropdownMenu from "$lib/components/ui/dropdown-menu/index.js";
	import { Badge } from "$lib/components/ui/badge/index.js";
	import { Button } from "$lib/components/ui/button/index.js";
	import { Label } from "$lib/components/ui/label/index.js";
	import { Input } from "$lib/components/ui/input/index.js";
	import * as RadioGroup from "$lib/components/ui/radio-group/index.js";
	import * as Select from "$lib/components/ui/select/index.js";
	import PlusIcon from "@lucide/svelte/icons/plus";
	import PencilIcon from "@lucide/svelte/icons/pencil";
	import ArrowRightIcon from "@lucide/svelte/icons/arrow-right";
	import MoreHorizontalIcon from "@lucide/svelte/icons/ellipsis";
	import EyeOffIcon from "@lucide/svelte/icons/eye-off";
	import EyeIcon from "@lucide/svelte/icons/eye";

	let { data, form, params }: { data: PageData; form: ActionData; params: { workspaceId: string } } = $props();

	const workspaceId = $derived(params.workspaceId);

	// ── Sheet state ────────────────────────────────────────────────────────

	type SheetMode =
		| { kind: "closed" }
		| { kind: "createAccount" }
		| { kind: "editAccount"; account: Account }
		| { kind: "addCurrency" };

	let sheetMode = $state<SheetMode>({ kind: "closed" });
	let isSubmitting = $state(false);

	// ── Create account form state ──────────────────────────────────────────

	let newAccountName = $state("");
	let newAccountKind = $state<"CashAccount" | "External">("CashAccount");
	let newAccountCurrency = $state("");
	let newAccountCanHaveAssets = $state(false);
	let newAccountSubType = $state<"Income" | "Expense">("Expense");

	// For adding a new currency inline
	let showAddCurrencyInline = $state(false);
	let inlineCurrencyCode = $state("");
	let isAddingCurrency = $state(false);

	// Edit account form state
	let editName = $state("");

	function openCreate() {
		newAccountName = "";
		newAccountKind = "CashAccount";
		newAccountCurrency = data.currencies[0]?.currencyCode ?? data.workspace.baseCurrency;
		newAccountCanHaveAssets = false;
		newAccountSubType = "Expense";
		showAddCurrencyInline = false;
		inlineCurrencyCode = "";
		sheetMode = { kind: "createAccount" };
	}

	function openEdit(account: Account) {
		editName = account.name;
		sheetMode = { kind: "editAccount", account };
	}

	function closeSheet() {
		sheetMode = { kind: "closed" };
		isSubmitting = false;
		showAddCurrencyInline = false;
	}

	function buildAccountTypeJson(): string {
		if (newAccountKind === "CashAccount") {
			const t = {
				kind: "CashAccount",
				currency: newAccountCurrency,
				canHaveAssets: newAccountCanHaveAssets,
			} satisfies AccountType;
			return JSON.stringify(t);
		}
		const t = {
			kind: "External",
			subType: newAccountSubType,
		} satisfies AccountType;
		return JSON.stringify(t);
	}

	// ── Balance helpers ────────────────────────────────────────────────────

	function getAccountBalance(accountId: string): string | null {
		const accountBalances = data.balanceMap[accountId];
		if (!accountBalances) return null;
		const entries = Object.entries(accountBalances);
		if (entries.length === 0) return null;
		if (entries.length === 1 && entries[0]) {
			const [currency, bal] = entries[0];
			return `${formatBalance(bal.balance)} ${currency}`;
		}
		return entries.map(([currency, bal]) => `${formatBalance(bal.balance)} ${currency}`).join(" | ");
	}

	// ── Currency management ───────────────────────────────────────────────

	const availableCurrenciesToAdd = $derived(
		FIAT_CURRENCIES.filter(
			(fc) => !data.currencies.some((wc) => wc.currencyCode === fc.code),
		).filter(
			(fc, i, arr) => arr.findIndex((x) => x.code === fc.code) === i,
		),
	);

	// ── After form action, close sheet on success ─────────────────────────

	$effect(() => {
		if (form?.success) closeSheet();
	});

	function accountBadgeVariant(t: AccountType): "default" | "secondary" | "outline" {
		switch (t.kind) {
			case "CashAccount":
				return "default";
			case "External":
				return t.subType === "Income" ? "secondary" : "outline";
			case "FxExchanger":
				return "outline";
		}
	}

	// ── Show disabled accounts ────────────────────────────────────────────

	let showDisabled = $state(false);
	const visibleAccounts = $derived(
		showDisabled ? data.accounts : data.accounts.filter((a) => a.enabled),
	);
	const disabledCount = $derived(data.accounts.filter((a) => !a.enabled).length);
</script>

<div class="flex items-center justify-between mb-6">
	<div>
		<h1 class="text-2xl font-semibold">{data.workspace.name}</h1>
		<p class="text-sm text-muted-foreground mt-0.5">
			Accounts — base currency: {data.workspace.baseCurrency}
		</p>
	</div>
	<Button onclick={openCreate}>
		<PlusIcon class="size-4 mr-2" />
		New account
	</Button>
</div>

{#if form && !form.success}
	<p class="mb-4 text-sm text-destructive">{form.error}</p>
{/if}

{#if visibleAccounts.length === 0 && disabledCount === 0}
	<div class="rounded-lg border border-dashed p-10 text-center text-muted-foreground">
		<p class="text-sm">No accounts yet. Create your first account to get started.</p>
	</div>
{:else}
	{#if disabledCount > 0}
		<button
			class="mb-3 text-xs text-muted-foreground hover:text-foreground"
			onclick={() => (showDisabled = !showDisabled)}
		>
			{showDisabled ? "Hide" : "Show"} {disabledCount} disabled account{disabledCount === 1 ? "" : "s"}
		</button>
	{/if}

	<Table.Root>
		<Table.Header>
			<Table.Row>
				<Table.Head>Account</Table.Head>
				<Table.Head>Type</Table.Head>
				<Table.Head class="text-right">Balance</Table.Head>
				<Table.Head class="w-12"></Table.Head>
			</Table.Row>
		</Table.Header>
		<Table.Body>
			{#each visibleAccounts as account (account.id)}
				<Table.Row class={account.enabled ? "" : "opacity-50"}>
					<Table.Cell>
						<a
							href={ROUTES.workspace.syncAccount(workspaceId, account.id)}
							class="font-medium hover:underline"
						>
							{account.name}
						</a>
						{#if !account.enabled}
							<span class="ml-2 text-xs text-muted-foreground">(disabled)</span>
						{/if}
					</Table.Cell>
					<Table.Cell>
						<Badge variant={accountBadgeVariant(account.accountType)}>
							{accountTypeLabel(account.accountType)}
						</Badge>
					</Table.Cell>
					<Table.Cell class="text-right font-mono text-sm">
						{getAccountBalance(account.id) ?? "—"}
					</Table.Cell>
					<Table.Cell>
						<DropdownMenu.Root>
							<DropdownMenu.Trigger>
								{#snippet child({ props })}
									<Button {...props} variant="ghost" size="icon" title="Account options">
										<MoreHorizontalIcon class="size-4" />
									</Button>
								{/snippet}
							</DropdownMenu.Trigger>
							<DropdownMenu.Content align="end">
								<DropdownMenu.Item>
									{#snippet child({ props })}
										<a {...props} href={ROUTES.workspace.syncAccount(workspaceId, account.id)}>
											<ArrowRightIcon class="size-4 mr-2" />
											View transactions
										</a>
									{/snippet}
								</DropdownMenu.Item>
								<DropdownMenu.Item onclick={() => openEdit(account)}>
									<PencilIcon class="size-4 mr-2" />
									Edit
								</DropdownMenu.Item>
								<DropdownMenu.Separator />
								<!-- Standalone form for toggling enabled — no sheet needed -->
								<form method="POST" action="?/toggleAccount" use:enhance>
									<input type="hidden" name="id" value={account.id} />
									<input type="hidden" name="enabled" value={account.enabled ? "false" : "true"} />
									<DropdownMenu.Item>
										{#snippet child({ props })}
											<button {...props} type="submit" class="w-full flex items-center">
												{#if account.enabled}
													<EyeOffIcon class="size-4 mr-2" />
													Disable
												{:else}
													<EyeIcon class="size-4 mr-2" />
													Enable
												{/if}
											</button>
										{/snippet}
									</DropdownMenu.Item>
								</form>
							</DropdownMenu.Content>
						</DropdownMenu.Root>
					</Table.Cell>
				</Table.Row>
			{/each}
		</Table.Body>
	</Table.Root>
{/if}

<!-- ── Create Account Sheet ───────────────────────────────────────────── -->

<Sheet.Root
	open={sheetMode.kind === "createAccount"}
	onOpenChange={(open) => { if (!open) closeSheet(); }}
>
	<Sheet.Content side="right" class="w-full sm:max-w-md overflow-y-auto">
		<Sheet.Header>
			<Sheet.Title>New account</Sheet.Title>
			<Sheet.Description>Add a new account to this workspace.</Sheet.Description>
		</Sheet.Header>

		{#if showAddCurrencyInline}
			<!-- ── Add Currency sub-form ── -->
			<div class="flex flex-col gap-4 px-4 py-2">
				<p class="text-sm text-muted-foreground">
					Choose a currency to add to this workspace.
				</p>
				<div class="flex flex-col gap-1.5">
					<Label>Currency</Label>
					<Select.Root
						type="single"
						value={inlineCurrencyCode}
						onValueChange={(v) => (inlineCurrencyCode = v)}
					>
						<Select.Trigger>
							{inlineCurrencyCode
								? FIAT_CURRENCIES.find((c) => c.code === inlineCurrencyCode)?.name ?? inlineCurrencyCode
								: "Select currency…"}
						</Select.Trigger>
						<Select.Content>
							{#each availableCurrenciesToAdd as fc (fc.code)}
								<Select.Item value={fc.code}>{fc.code} — {fc.name}</Select.Item>
							{/each}
						</Select.Content>
					</Select.Root>
				</div>
				<form
					method="POST"
					action="?/addCurrency"
					use:enhance={() => {
						isAddingCurrency = true;
						return async ({ update, result }) => {
							await update({ reset: false });
							isAddingCurrency = false;
							if (result.type === "success") {
								newAccountCurrency = inlineCurrencyCode;
								showAddCurrencyInline = false;
							}
						};
					}}
					class="flex gap-2"
				>
					<input type="hidden" name="currencyCode" value={inlineCurrencyCode} />
					<Button
						type="button"
						variant="outline"
						class="flex-1"
						onclick={() => (showAddCurrencyInline = false)}
					>
						Cancel
					</Button>
					<Button
						type="submit"
						class="flex-1"
						disabled={!inlineCurrencyCode || isAddingCurrency}
					>
						{isAddingCurrency ? "Adding…" : "Add currency"}
					</Button>
				</form>
			</div>
		{:else}
			<!-- ── Main create account form ─────────────────────────────── -->
			<form
				method="POST"
				action="?/createAccount"
				use:enhance={() => {
					isSubmitting = true;
					return async ({ update }) => {
						await update();
						isSubmitting = false;
					};
				}}
				class="flex flex-col gap-4 px-4 py-2"
			>
				<input type="hidden" name="accountType" value={buildAccountTypeJson()} />

				<div class="flex flex-col gap-1.5">
					<Label for="name">Name</Label>
					<Input
						id="name"
						name="name"
						placeholder="e.g. Checking, Salary, Groceries"
						bind:value={newAccountName}
						required
					/>
				</div>

				<div class="flex flex-col gap-2">
					<Label>Account type</Label>
					<RadioGroup.Root
						value={newAccountKind}
						onValueChange={(v) => {
							if (v === "CashAccount" || v === "External") newAccountKind = v;
						}}
						class="flex gap-4"
					>
						<div class="flex items-center gap-2">
							<RadioGroup.Item value="CashAccount" id="kind-cash" />
							<Label for="kind-cash">Cash account</Label>
						</div>
						<div class="flex items-center gap-2">
							<RadioGroup.Item value="External" id="kind-external" />
							<Label for="kind-external">External</Label>
						</div>
					</RadioGroup.Root>
				</div>

				{#if newAccountKind === "CashAccount"}
					<div class="flex flex-col gap-1.5">
						<Label for="currency">Currency</Label>
						<Select.Root
							type="single"
							value={newAccountCurrency}
							onValueChange={(v) => {
								if (v === "__add__") {
									showAddCurrencyInline = true;
									inlineCurrencyCode = "";
								} else {
									newAccountCurrency = v;
								}
							}}
						>
							<Select.Trigger>
								{newAccountCurrency || "Select currency…"}
							</Select.Trigger>
							<Select.Content>
								{#each data.currencies as wc (wc.currencyCode)}
									<Select.Item value={wc.currencyCode}>
										{wc.currencyCode} — {wc.currencyName}
									</Select.Item>
								{/each}
								{#if availableCurrenciesToAdd.length > 0}
									<Select.Separator />
									<Select.Item value="__add__" class="text-muted-foreground">
										Add currency…
									</Select.Item>
								{/if}
							</Select.Content>
						</Select.Root>
					</div>

					<div class="flex items-center gap-2">
						<input
							type="checkbox"
							id="canHaveAssets"
							bind:checked={newAccountCanHaveAssets}
							class="rounded border-input"
						/>
						<Label for="canHaveAssets">Can hold assets (stocks, crypto, etc.)</Label>
					</div>
				{/if}

				{#if newAccountKind === "External"}
					<div class="flex flex-col gap-2">
						<Label>Sub-type</Label>
						<RadioGroup.Root
							value={newAccountSubType}
							onValueChange={(v) => {
								if (v === "Income" || v === "Expense") newAccountSubType = v;
							}}
							class="flex gap-4"
						>
							<div class="flex items-center gap-2">
								<RadioGroup.Item value="Income" id="sub-income" />
								<Label for="sub-income">Income source</Label>
							</div>
							<div class="flex items-center gap-2">
								<RadioGroup.Item value="Expense" id="sub-expense" />
								<Label for="sub-expense">Expense category</Label>
							</div>
						</RadioGroup.Root>
					</div>
				{/if}

				<Sheet.Footer class="mt-2">
					<Button type="button" variant="outline" onclick={closeSheet}>Cancel</Button>
					<Button type="submit" disabled={isSubmitting}>
						{isSubmitting ? "Creating…" : "Create account"}
					</Button>
				</Sheet.Footer>
			</form>
		{/if}
	</Sheet.Content>
</Sheet.Root>

<!-- ── Edit Account Sheet ─────────────────────────────────────────────── -->

<Sheet.Root
	open={sheetMode.kind === "editAccount"}
	onOpenChange={(open) => { if (!open) closeSheet(); }}
>
	<Sheet.Content side="right" class="w-full sm:max-w-md">
		<Sheet.Header>
			<Sheet.Title>Edit account</Sheet.Title>
			{#if sheetMode.kind === "editAccount"}
				<Sheet.Description>
					{accountTypeLabel(sheetMode.account.accountType)}
				</Sheet.Description>
			{/if}
		</Sheet.Header>

		{#if sheetMode.kind === "editAccount"}
			<form
				method="POST"
				action="?/updateAccount"
				use:enhance={() => {
					isSubmitting = true;
					return async ({ update }) => {
						await update();
						isSubmitting = false;
					};
				}}
				class="flex flex-col gap-4 px-4 py-2"
			>
				<input type="hidden" name="id" value={sheetMode.account.id} />
				<input type="hidden" name="enabled" value={sheetMode.account.enabled ? "true" : "false"} />

				<div class="flex flex-col gap-1.5">
					<Label for="edit-name">Name</Label>
					<Input id="edit-name" name="name" bind:value={editName} required />
				</div>

				<Sheet.Footer class="mt-2">
					<Button type="button" variant="outline" onclick={closeSheet}>Cancel</Button>
					<Button type="submit" disabled={isSubmitting}>
						{isSubmitting ? "Saving…" : "Save changes"}
					</Button>
				</Sheet.Footer>
			</form>
		{/if}
	</Sheet.Content>
</Sheet.Root>
