<script lang="ts">
  import type { PageData } from "./$types";
  let { data }: { data: PageData } = $props();
</script>

<main>
  <h1>Hempire</h1>
  <p>Welcome. Use the navigation above to access CRM and Ledger.</p>
  <p class="customer-id">Customer ID: <code>{data.customerId}</code></p>
</main>

<style>
  main {
    padding: 2rem;
  }
  .customer-id {
    color: #6b7280;
    font-size: 0.9rem;
  }
</style>
