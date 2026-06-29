<script lang="ts">
	import type { PageData, ActionData } from './$types';
	let { data, form }: { data: PageData; form: ActionData } = $props();
</script>

<main>
	<h1>Complete your registration</h1>
	{#if data.userName}
		<p class="user-hint">Logged in as <strong>{data.userName}</strong></p>
	{/if}
	<p>Enter your invite code to get started.</p>

	{#if form?.error}
		<p class="error">{form.error}</p>
	{/if}

	<form method="POST">
		<label>
			Invite code
			<input type="text" name="inviteId" value={data.inviteId ?? ''} required placeholder="inv_..." />
		</label>
		<button type="submit">Continue</button>
	</form>
</main>

<style>
	main {
		max-width: 400px;
		margin: 4rem auto;
		padding: 2rem;
	}
	label {
		display: block;
		margin-bottom: 1rem;
	}
	input {
		display: block;
		width: 100%;
		margin-top: 0.25rem;
	}
	.error {
		color: #991b1b;
	}
	.user-hint {
		color: #6b7280;
		font-size: 0.9rem;
	}
</style>
