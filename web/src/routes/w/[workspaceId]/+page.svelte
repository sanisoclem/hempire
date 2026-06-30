<script lang="ts">
  import type { PageData } from './$types';

  let { data }: { data: PageData } = $props();
</script>

<h1 class="text-2xl font-semibold mb-6">{data.workspace.name}</h1>

<dl class="grid grid-cols-[max-content_1fr] gap-x-6 gap-y-2 text-sm">
  <dt class="text-gray-500">Base currency</dt>
  <dd class="m-0">{data.workspace.baseCurrency}</dd>

  <dt class="text-gray-500">ID</dt>
  <dd class="m-0"><code class="font-mono text-xs bg-gray-100 px-1 py-0.5 rounded">{data.workspace.id}</code></dd>
</dl>
