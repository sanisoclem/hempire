<script lang="ts">
  import type { Snippet } from 'svelte';
  import { ROUTES } from '$lib/routes';
  import type { LayoutData } from './$types';

  let { children, data }: { children: Snippet; data: LayoutData } = $props();
</script>

<div class="flex min-h-screen">
  <aside class="w-56 border-r border-gray-200 flex flex-col gap-6 p-4">
    <span class="text-sm font-semibold text-gray-700">{data.user.userName ?? 'User'}</span>

    <nav class="flex flex-col gap-1">
      {#each data.workspaces as ws (ws.id)}
        <a
          href={ROUTES.workspace.detail(ws.id)}
          class="px-2 py-1.5 rounded text-sm text-gray-700 hover:bg-gray-100"
        >{ws.name}</a>
      {/each}
      <a
        href={ROUTES.workspace.new}
        class="mt-2 px-2 py-1.5 rounded text-xs text-gray-400 hover:bg-gray-100"
      >+ New workspace</a>
    </nav>
  </aside>

  <main class="flex-1 p-8">
    {@render children()}
  </main>
</div>
