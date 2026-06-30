<script lang="ts">
	import NavUser from "./nav-user.svelte";
	import WorkspaceSwitcher from "./workspace-switcher.svelte";
	import * as Sidebar from "$lib/components/ui/sidebar/index.js";
	import type { Workspace } from "$lib/types";
	import type { ComponentProps } from "svelte";
	import { page } from "$app/state";
	import { ROUTES } from "$lib/routes";
	import RefreshCwIcon from "@lucide/svelte/icons/refresh-cw";
	import BarChart2Icon from "@lucide/svelte/icons/bar-chart-2";
	import SlidersHorizontalIcon from "@lucide/svelte/icons/sliders-horizontal";
	import TargetIcon from "@lucide/svelte/icons/target";

	let {
		workspaces,
		activeWorkspaceId,
		ref = $bindable(null),
		...restProps
	}: ComponentProps<typeof Sidebar.Root> & {
		workspaces: Workspace[];
		activeWorkspaceId: string | undefined;
	} = $props();

	const navItems = $derived(
		activeWorkspaceId
			? [
					{
						label: "Sync",
						href: ROUTES.workspace.sync(activeWorkspaceId),
						icon: RefreshCwIcon,
					},
					{
						label: "Observe",
						href: ROUTES.workspace.observe(activeWorkspaceId),
						icon: BarChart2Icon,
					},
					{
						label: "Adjust",
						href: ROUTES.workspace.adjust(activeWorkspaceId),
						icon: SlidersHorizontalIcon,
					},
					{
						label: "Strategize",
						href: ROUTES.workspace.strategize(activeWorkspaceId),
						icon: TargetIcon,
					},
				]
			: [],
	);

	function isActive(href: string): boolean {
		return page.url.pathname.startsWith(href);
	}
</script>

<Sidebar.Root bind:ref variant="inset" {...restProps}>
	<Sidebar.Header>
		<div
			class="px-2 py-1 text-xs font-semibold text-sidebar-foreground/50 uppercase tracking-wider"
		>
			Hempire
		</div>
		<WorkspaceSwitcher {workspaces} {activeWorkspaceId} />
	</Sidebar.Header>

	<Sidebar.Content>
		{#if navItems.length > 0}
			<Sidebar.Group>
				<Sidebar.GroupContent>
					<Sidebar.Menu>
						{#each navItems as item (item.href)}
							<Sidebar.MenuItem>
								<Sidebar.MenuButton isActive={isActive(item.href)}>
									{#snippet child({ props })}
										<a {...props} href={item.href}>
											<item.icon />
											<span>{item.label}</span>
										</a>
									{/snippet}
								</Sidebar.MenuButton>
							</Sidebar.MenuItem>
						{/each}
					</Sidebar.Menu>
				</Sidebar.GroupContent>
			</Sidebar.Group>
		{/if}
	</Sidebar.Content>

	<Sidebar.Footer>
		<NavUser />
	</Sidebar.Footer>

	<Sidebar.Rail />
</Sidebar.Root>
