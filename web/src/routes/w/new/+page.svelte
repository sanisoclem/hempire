<script lang="ts">
  import { enhance } from '$app/forms';
  import type { ActionData } from './$types';

  let { form }: { form: ActionData } = $props();
</script>

<h1 class="text-2xl font-semibold mb-6">Create workspace</h1>

<form method="POST" use:enhance class="flex flex-col gap-4 max-w-sm">
  <label class="flex flex-col gap-1 text-sm text-gray-700">
    Name
    <input
      name="name"
      type="text"
      required
      class="px-3 py-2 border border-gray-300 rounded text-base focus:outline-none focus:ring-2 focus:ring-gray-400"
    />
  </label>

  <label class="flex flex-col gap-1 text-sm text-gray-700">
    Base currency
    <input
      name="baseCurrency"
      type="text"
      placeholder="e.g. USD"
      required
      class="px-3 py-2 border border-gray-300 rounded text-base focus:outline-none focus:ring-2 focus:ring-gray-400"
    />
  </label>

  {#if form?.error}
    <p class="text-sm text-red-600">{form.error}</p>
  {/if}

  <button
    type="submit"
    class="self-start px-4 py-2 bg-gray-900 text-white rounded text-sm hover:bg-gray-700 cursor-pointer"
  >Create</button>
</form>
