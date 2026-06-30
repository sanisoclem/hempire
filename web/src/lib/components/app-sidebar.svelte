<script lang="ts">
	import NavUser from "./nav-user.svelte";
	import WorkspaceSwitcher from "./workspace-switcher.svelte";
	import * as Sidebar from "$lib/components/ui/sidebar/index.js";
	import type { Ledger } from "$lib/types";
	import type { ComponentProps } from "svelte";

	let {
		workspaces,
		activeWorkspaceId,
		user,
		ref = $bindable(null),
		...restProps
	}: ComponentProps<typeof Sidebar.Root> & {
		workspaces: Ledger[];
		activeWorkspaceId: string | undefined;
		user: { userName: string | null };
	} = $props();
</script>

<Sidebar.Root bind:ref variant="inset" {...restProps}>
	<Sidebar.Header>
		<div class="px-2 py-1 text-xs font-semibold text-sidebar-foreground/50 uppercase tracking-wider">
			Hempire
		</div>
		<WorkspaceSwitcher {workspaces} {activeWorkspaceId} />
	</Sidebar.Header>

	<Sidebar.Content>
		<!-- nav items go here as the app grows -->
	</Sidebar.Content>

	<Sidebar.Footer>
		<NavUser {user} />
	</Sidebar.Footer>

	<Sidebar.Rail />
</Sidebar.Root>
