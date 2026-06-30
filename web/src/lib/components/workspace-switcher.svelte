<script lang="ts">
	import { goto } from "$app/navigation";
	import * as DropdownMenu from "$lib/components/ui/dropdown-menu/index.js";
	import * as Sidebar from "$lib/components/ui/sidebar/index.js";
	import { useSidebar } from "$lib/components/ui/sidebar/index.js";
	import { ROUTES } from "$lib/routes";
	import type { Workspace } from "$lib/types";
	import ChevronsUpDownIcon from "@lucide/svelte/icons/chevrons-up-down";
	import LayersIcon from "@lucide/svelte/icons/layers";
	import PlusIcon from "@lucide/svelte/icons/plus";

	let {
		workspaces,
		activeWorkspaceId,
	}: {
		workspaces: Workspace[];
		activeWorkspaceId: string | undefined;
	} = $props();

	const sidebar = useSidebar();

	const activeWorkspace = $derived(
		workspaces.find((w) => w.id === activeWorkspaceId) ?? workspaces[0]
	);
</script>

<Sidebar.Menu>
	<Sidebar.MenuItem>
		<DropdownMenu.Root>
			<DropdownMenu.Trigger>
				{#snippet child({ props })}
					<Sidebar.MenuButton
						{...props}
						size="lg"
						class="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
					>
						<div
							class="bg-sidebar-primary text-sidebar-primary-foreground flex aspect-square size-8 items-center justify-center rounded-lg"
						>
							<LayersIcon class="size-4" />
						</div>
						{#if activeWorkspace}
							<div class="grid flex-1 text-start text-sm leading-tight">
								<span class="truncate font-medium">{activeWorkspace.name}</span>
								<span class="truncate text-xs">{activeWorkspace.baseCurrency}</span>
							</div>
						{:else}
							<span class="flex-1 text-sm text-muted-foreground">No workspace</span>
						{/if}
						<ChevronsUpDownIcon class="ms-auto size-4" />
					</Sidebar.MenuButton>
				{/snippet}
			</DropdownMenu.Trigger>
			<DropdownMenu.Content
				class="w-(--bits-dropdown-menu-anchor-width) min-w-56 rounded-lg"
				align="start"
				side={sidebar.isMobile ? "bottom" : "right"}
				sideOffset={4}
			>
				<DropdownMenu.Label class="text-muted-foreground text-xs">Workspaces</DropdownMenu.Label>
				{#each workspaces as ws (ws.id)}
					<DropdownMenu.Item
						onSelect={() => goto(ROUTES.workspace.detail(ws.id))}
						class="gap-2 p-2"
					>
						<div class="flex size-6 items-center justify-center rounded-md border">
							<LayersIcon class="size-3.5 shrink-0" />
						</div>
						<span class="flex-1 truncate">{ws.name}</span>
						<span class="text-muted-foreground text-xs">{ws.baseCurrency}</span>
					</DropdownMenu.Item>
				{/each}
				<DropdownMenu.Separator />
				<DropdownMenu.Item onSelect={() => goto(ROUTES.workspace.new)} class="gap-2 p-2">
					<div class="flex size-6 items-center justify-center rounded-md border bg-transparent">
						<PlusIcon class="size-4" />
					</div>
					<span class="text-muted-foreground font-medium">New workspace</span>
				</DropdownMenu.Item>
			</DropdownMenu.Content>
		</DropdownMenu.Root>
	</Sidebar.MenuItem>
</Sidebar.Menu>
