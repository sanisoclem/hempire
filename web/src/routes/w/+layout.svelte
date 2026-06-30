<script lang="ts">
  import type { Snippet } from "svelte";
  import { page } from "$app/state";
  import AppSidebar from "$lib/components/app-sidebar.svelte";
  import * as Sidebar from "$lib/components/ui/sidebar/index.js";
  import type { LayoutData } from "./$types";

  let { children, data }: { children: Snippet; data: LayoutData } = $props();

  const activeWorkspaceId = $derived(
    page.params.workspaceId as string | undefined,
  );
</script>

<Sidebar.Provider>
  <AppSidebar workspaces={data.workspaces} {activeWorkspaceId} />
  <Sidebar.Inset>
    <header
      class="flex h-12 shrink-0 items-center gap-2 border-b border-sidebar-border px-4"
    >
      <Sidebar.Trigger class="-ms-1" />
    </header>
    <div class="flex flex-1 flex-col p-6">
      {@render children()}
    </div>
  </Sidebar.Inset>
</Sidebar.Provider>
