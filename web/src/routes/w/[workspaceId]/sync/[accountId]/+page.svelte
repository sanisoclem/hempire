<script lang="ts">
	import { enhance } from "$app/forms";
	import { ROUTES } from "$lib/routes";
	import type { PageData, ActionData } from "./$types";
	import type { JournalEntry, AccountType } from "$lib/domain";
	import { accountTypeLabel, formatBalance } from "$lib/domain";
	import * as Table from "$lib/components/ui/table/index.js";
	import * as Sheet from "$lib/components/ui/sheet/index.js";
	import * as AlertDialog from "$lib/components/ui/alert-dialog/index.js";
	import { Badge } from "$lib/components/ui/badge/index.js";
	import { Button } from "$lib/components/ui/button/index.js";
	import { Label } from "$lib/components/ui/label/index.js";
	import { Input } from "$lib/components/ui/input/index.js";
	import * as RadioGroup from "$lib/components/ui/radio-group/index.js";
	import * as Select from "$lib/components/ui/select/index.js";
	import ArrowLeftIcon from "@lucide/svelte/icons/arrow-left";
	import PlusIcon from "@lucide/svelte/icons/plus";
	import PencilIcon from "@lucide/svelte/icons/pencil";
	import Trash2Icon from "@lucide/svelte/icons/trash-2";

	let {
		data,
		form,
		params,
	}: { data: PageData; form: ActionData; params: { workspaceId: string; accountId: string } } =
		$props();

	const workspaceId = $derived(params.workspaceId);
	const accountId = $derived(params.accountId);

	// ── Sheet state ───────────────────────────────────────────────────────

	type SheetMode =
		| { kind: "closed" }
		| { kind: "createEntry" }
		| { kind: "editEntry"; entry: JournalEntry };

	let sheetMode = $state<SheetMode>({ kind: "closed" });
	let isSubmitting = $state(false);

	// ── Delete dialog ─────────────────────────────────────────────────────

	let pendingDeleteId = $state<string | null>(null);
	let isDeleting = $state(false);
	let deleteForm = $state<HTMLFormElement | null>(null);

	function requestDelete(entryId: string) {
		pendingDeleteId = entryId;
	}

	function cancelDelete() {
		pendingDeleteId = null;
	}

	// ── Form state for entry ──────────────────────────────────────────────

	let entryDate = $state(new Date().toISOString().slice(0, 10));
	let entryDirection = $state<"inflow" | "outflow">("outflow");
	let entryAmount = $state("");
	let entryOtherAccountId = $state("");

	function openCreate() {
		entryDate = new Date().toISOString().slice(0, 10);
		entryDirection = "outflow";
		entryAmount = "";
		entryOtherAccountId = "";
		sheetMode = { kind: "createEntry" };
	}

	function openEdit(entry: JournalEntry) {
		if (entry.lineItems.kind !== "SameCurrencyTransfer") return;
		const li = entry.lineItems;
		entryDate = entry.date;
		entryAmount = li.amount;
		if (li.accountTo === accountId) {
			entryDirection = "inflow";
			entryOtherAccountId = li.accountFrom;
		} else {
			entryDirection = "outflow";
			entryOtherAccountId = li.accountTo;
		}
		sheetMode = { kind: "editEntry", entry };
	}

	function closeSheet() {
		sheetMode = { kind: "closed" };
		isSubmitting = false;
	}

	$effect(() => {
		if (form?.success) {
			closeSheet();
			pendingDeleteId = null;
		}
	});

	// ── Current account ───────────────────────────────────────────────────

	const account = $derived(data.account);
	const accountCurrency = $derived(
		account.accountType.kind === "CashAccount" ? account.accountType.currency : null,
	);

	const compatibleAccounts = $derived(
		data.allAccounts.filter((a) => {
			if (a.id === accountId) return false;
			if (a.accountType.kind === "FxExchanger") return false;
			if (account.accountType.kind === "CashAccount") {
				if (a.accountType.kind === "External") return true;
				if (a.accountType.kind === "CashAccount") {
					return a.accountType.currency === accountCurrency;
				}
			}
			if (account.accountType.kind === "External") {
				return a.accountType.kind === "CashAccount";
			}
			return false;
		}),
	);

	function buildLineItemsJson(): string {
		const fromAccount = entryDirection === "outflow" ? accountId : entryOtherAccountId;
		const toAccount = entryDirection === "outflow" ? entryOtherAccountId : accountId;

		const otherAccount = data.allAccounts.find((a) => a.id === entryOtherAccountId);
		const otherCurrency =
			otherAccount?.accountType.kind === "CashAccount"
				? otherAccount.accountType.currency
				: null;
		const currency = accountCurrency ?? otherCurrency ?? data.workspace.baseCurrency;

		return JSON.stringify({
			kind: "SameCurrencyTransfer",
			amount: entryAmount,
			currency,
			accountFrom: fromAccount,
			accountTo: toAccount,
		});
	}

	// ── Balance display ───────────────────────────────────────────────────

	const accountBalances = $derived(data.balanceMap[accountId]);
	const currentBalance = $derived(
		accountBalances && accountCurrency ? accountBalances[accountCurrency] : null,
	);

	// ── Transaction display ───────────────────────────────────────────────

	function getEntryAmount(
		entry: JournalEntry,
	): { amount: string; currency: string; sign: "+" | "-" } | null {
		if (entry.lineItems.kind !== "SameCurrencyTransfer") return null;
		const li = entry.lineItems;
		const isInflow = li.accountTo === accountId;
		return {
			amount: formatBalance(li.amount),
			currency: li.currency,
			sign: isInflow ? "+" : "-",
		};
	}

	function getEntryCounterpart(entry: JournalEntry): string {
		if (entry.lineItems.kind !== "SameCurrencyTransfer") return "—";
		const li = entry.lineItems;
		const counterpartId = li.accountTo === accountId ? li.accountFrom : li.accountTo;
		return data.allAccounts.find((a) => a.id === counterpartId)?.name ?? counterpartId;
	}

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
</script>

<!-- ── Header ────────────────────────────────────────────────────────────── -->

<div class="mb-6">
	<a
		href={ROUTES.workspace.sync(workspaceId)}
		class="text-sm text-muted-foreground hover:text-foreground inline-flex items-center gap-1 mb-3"
	>
		<ArrowLeftIcon class="size-3" />
		Back to accounts
	</a>

	<div class="flex items-start justify-between">
		<div>
			<div class="flex items-center gap-2 mb-1">
				<h1 class="text-2xl font-semibold">{account.name}</h1>
				<Badge variant={accountBadgeVariant(account.accountType)}>
					{accountTypeLabel(account.accountType)}
				</Badge>
			</div>
			{#if currentBalance}
				<p class="text-sm text-muted-foreground">
					Balance: <span class="font-mono font-medium text-foreground">
						{formatBalance(currentBalance.balance)} {accountCurrency}
					</span>
				</p>
			{:else if account.accountType.kind === "External"}
				<p class="text-sm text-muted-foreground">External account — no balance tracked</p>
			{:else}
				<p class="text-sm text-muted-foreground">No transactions yet</p>
			{/if}
		</div>
		<Button onclick={openCreate}>
			<PlusIcon class="size-4 mr-2" />
			New transaction
		</Button>
	</div>
</div>

{#if form && !form.success}
	<p class="mb-4 text-sm text-destructive">{form.error}</p>
{/if}

{#if data.entries.length === 0}
	<div class="rounded-lg border border-dashed p-10 text-center text-muted-foreground">
		<p class="text-sm">No transactions yet. Record your first transaction to get started.</p>
	</div>
{:else}
	<Table.Root>
		<Table.Header>
			<Table.Row>
				<Table.Head class="w-32">Date</Table.Head>
				<Table.Head>Counterpart</Table.Head>
				<Table.Head class="text-right">Amount</Table.Head>
				<Table.Head class="w-24"></Table.Head>
			</Table.Row>
		</Table.Header>
		<Table.Body>
			{#each data.entries as entry (entry.id)}
				{@const amt = getEntryAmount(entry)}
				<Table.Row>
					<Table.Cell class="font-mono text-sm text-muted-foreground">{entry.date}</Table.Cell>
					<Table.Cell>{getEntryCounterpart(entry)}</Table.Cell>
					<Table.Cell class="text-right font-mono text-sm">
						{#if amt}
							<span class={amt.sign === "+" ? "text-green-600" : "text-red-600"}>
								{amt.sign}{amt.amount}
							</span>
							<span class="text-muted-foreground ml-1">{amt.currency}</span>
						{:else}
							<span class="text-muted-foreground">—</span>
						{/if}
					</Table.Cell>
					<Table.Cell>
						{#if entry.lineItems.kind === "SameCurrencyTransfer"}
							<div class="flex gap-1 justify-end">
								<Button
									variant="ghost"
									size="icon"
									onclick={() => openEdit(entry)}
									title="Edit transaction"
								>
									<PencilIcon class="size-4" />
								</Button>
								<Button
									variant="ghost"
									size="icon"
									class="text-destructive hover:text-destructive"
									onclick={() => requestDelete(entry.id)}
									title="Delete transaction"
								>
									<Trash2Icon class="size-4" />
								</Button>
							</div>
						{/if}
					</Table.Cell>
				</Table.Row>
			{/each}
		</Table.Body>
	</Table.Root>
{/if}

<!-- ── Delete Confirmation Dialog ────────────────────────────────────────── -->

<AlertDialog.Root open={pendingDeleteId !== null} onOpenChange={(v) => { if (!v) cancelDelete(); }}>
	<AlertDialog.Content>
		<AlertDialog.Header>
			<AlertDialog.Title>Delete transaction?</AlertDialog.Title>
			<AlertDialog.Description>
				This will permanently delete the transaction and revert its effect on all account balances.
				This cannot be undone.
			</AlertDialog.Description>
		</AlertDialog.Header>
		<AlertDialog.Footer>
			<AlertDialog.Cancel onclick={cancelDelete}>Cancel</AlertDialog.Cancel>
			<form
				method="POST"
				action="?/deleteEntry"
				bind:this={deleteForm}
				use:enhance={() => {
					isDeleting = true;
					return async ({ update }) => {
						await update();
						isDeleting = false;
						pendingDeleteId = null;
					};
				}}
			>
				<input type="hidden" name="id" value={pendingDeleteId ?? ""} />
				<AlertDialog.Action type="submit" disabled={isDeleting}>
					{isDeleting ? "Deleting…" : "Delete"}
				</AlertDialog.Action>
			</form>
		</AlertDialog.Footer>
	</AlertDialog.Content>
</AlertDialog.Root>

<!-- ── Create Transaction Sheet ──────────────────────────────────────────── -->

<Sheet.Root
	open={sheetMode.kind === "createEntry"}
	onOpenChange={(open) => { if (!open) closeSheet(); }}
>
	<Sheet.Content side="right" class="w-full sm:max-w-md">
		<Sheet.Header>
			<Sheet.Title>New transaction</Sheet.Title>
			<Sheet.Description>Record a transfer for {account.name}.</Sheet.Description>
		</Sheet.Header>

		<form
			method="POST"
			action="?/createEntry"
			use:enhance={() => {
				isSubmitting = true;
				return async ({ update }) => {
					await update();
					isSubmitting = false;
				};
			}}
			class="flex flex-col gap-4 px-4 py-2"
		>
			<input type="hidden" name="lineItems" value={buildLineItemsJson()} />

			<div class="flex flex-col gap-1.5">
				<Label for="date">Date</Label>
				<Input type="date" id="date" name="date" bind:value={entryDate} required />
			</div>

			<div class="flex flex-col gap-2">
				<Label>Direction</Label>
				<RadioGroup.Root
					value={entryDirection}
					onValueChange={(v) => {
						if (v === "inflow" || v === "outflow") entryDirection = v;
					}}
					class="flex gap-4"
				>
					<div class="flex items-center gap-2">
						<RadioGroup.Item value="outflow" id="dir-out" />
						<Label for="dir-out">Outflow (money leaving)</Label>
					</div>
					<div class="flex items-center gap-2">
						<RadioGroup.Item value="inflow" id="dir-in" />
						<Label for="dir-in">Inflow (money arriving)</Label>
					</div>
				</RadioGroup.Root>
			</div>

			<div class="flex flex-col gap-1.5">
				<Label for="amount">Amount</Label>
				<Input
					type="number"
					id="amount"
					name="amount"
					min="0.01"
					step="0.01"
					placeholder="0.00"
					bind:value={entryAmount}
					required
				/>
				{#if accountCurrency}
					<p class="text-xs text-muted-foreground">{accountCurrency}</p>
				{/if}
			</div>

			<div class="flex flex-col gap-1.5">
				<Label>
					{entryDirection === "outflow" ? "To account" : "From account"}
				</Label>
				<Select.Root
					type="single"
					value={entryOtherAccountId}
					onValueChange={(v) => (entryOtherAccountId = v)}
				>
					<Select.Trigger>
						{compatibleAccounts.find((a) => a.id === entryOtherAccountId)?.name ??
							"Select account…"}
					</Select.Trigger>
					<Select.Content>
						{#each compatibleAccounts as acc (acc.id)}
							<Select.Item value={acc.id}>{acc.name}</Select.Item>
						{/each}
						{#if compatibleAccounts.length === 0}
							<div class="px-2 py-1.5 text-sm text-muted-foreground">
								No compatible accounts. Create another account first.
							</div>
						{/if}
					</Select.Content>
				</Select.Root>
			</div>

			<Sheet.Footer class="mt-2">
				<Button type="button" variant="outline" onclick={closeSheet}>Cancel</Button>
				<Button
					type="submit"
					disabled={isSubmitting || !entryOtherAccountId || !entryAmount}
				>
					{isSubmitting ? "Saving…" : "Save transaction"}
				</Button>
			</Sheet.Footer>
		</form>
	</Sheet.Content>
</Sheet.Root>

<!-- ── Edit Transaction Sheet ────────────────────────────────────────────── -->

<Sheet.Root
	open={sheetMode.kind === "editEntry"}
	onOpenChange={(open) => { if (!open) closeSheet(); }}
>
	<Sheet.Content side="right" class="w-full sm:max-w-md">
		<Sheet.Header>
			<Sheet.Title>Edit transaction</Sheet.Title>
		</Sheet.Header>

		{#if sheetMode.kind === "editEntry"}
			<form
				method="POST"
				action="?/updateEntry"
				use:enhance={() => {
					isSubmitting = true;
					return async ({ update }) => {
						await update();
						isSubmitting = false;
					};
				}}
				class="flex flex-col gap-4 px-4 py-2"
			>
				<input type="hidden" name="id" value={sheetMode.entry.id} />
				<input type="hidden" name="lineItems" value={buildLineItemsJson()} />

				<div class="flex flex-col gap-1.5">
					<Label for="edit-date">Date</Label>
					<Input type="date" id="edit-date" name="date" bind:value={entryDate} required />
				</div>

				<div class="flex flex-col gap-2">
					<Label>Direction</Label>
					<RadioGroup.Root
						value={entryDirection}
						onValueChange={(v) => {
							if (v === "inflow" || v === "outflow") entryDirection = v;
						}}
						class="flex gap-4"
					>
						<div class="flex items-center gap-2">
							<RadioGroup.Item value="outflow" id="edit-dir-out" />
							<Label for="edit-dir-out">Outflow</Label>
						</div>
						<div class="flex items-center gap-2">
							<RadioGroup.Item value="inflow" id="edit-dir-in" />
							<Label for="edit-dir-in">Inflow</Label>
						</div>
					</RadioGroup.Root>
				</div>

				<div class="flex flex-col gap-1.5">
					<Label for="edit-amount">Amount</Label>
					<Input
						type="number"
						id="edit-amount"
						min="0.01"
						step="0.01"
						bind:value={entryAmount}
						required
					/>
				</div>

				<div class="flex flex-col gap-1.5">
					<Label>
						{entryDirection === "outflow" ? "To account" : "From account"}
					</Label>
					<Select.Root
						type="single"
						value={entryOtherAccountId}
						onValueChange={(v) => (entryOtherAccountId = v)}
					>
						<Select.Trigger>
							{compatibleAccounts.find((a) => a.id === entryOtherAccountId)?.name ??
								"Select account…"}
						</Select.Trigger>
						<Select.Content>
							{#each compatibleAccounts as acc (acc.id)}
								<Select.Item value={acc.id}>{acc.name}</Select.Item>
							{/each}
						</Select.Content>
					</Select.Root>
				</div>

				<Sheet.Footer class="mt-2">
					<Button type="button" variant="outline" onclick={closeSheet}>Cancel</Button>
					<Button
						type="submit"
						disabled={isSubmitting || !entryOtherAccountId || !entryAmount}
					>
						{isSubmitting ? "Saving…" : "Save changes"}
					</Button>
				</Sheet.Footer>
			</form>
		{/if}
	</Sheet.Content>
</Sheet.Root>
