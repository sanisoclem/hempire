<script lang="ts">
	import type { PageData, ActionData } from './$types';
	let { data, form }: { data: PageData; form: ActionData } = $props();
</script>

<main class="max-w-sm mx-auto mt-16 px-8 py-8">
	<h1 class="text-2xl font-semibold mb-4">Complete your registration</h1>

	{#if data.userName}
		<p class="text-sm text-gray-500 mb-2">Logged in as <strong>{data.userName}</strong></p>
	{/if}
	<p class="text-sm text-gray-600 mb-6">Enter your invite code to get started.</p>

	{#if form?.error}
		<p class="text-sm text-red-700 mb-4">{form.error}</p>
	{/if}

	<form method="POST" class="flex flex-col gap-4">
		<label class="flex flex-col gap-1 text-sm text-gray-700">
			Invite code
			<input
				type="text"
				name="inviteId"
				value={data.inviteId ?? ''}
				required
				placeholder="inv_..."
				class="px-3 py-2 border border-gray-300 rounded text-base focus:outline-none focus:ring-2 focus:ring-gray-400"
			/>
		</label>
		<button
			type="submit"
			class="px-4 py-2 bg-gray-900 text-white rounded text-sm hover:bg-gray-700 cursor-pointer self-start"
		>Continue</button>
	</form>
</main>
