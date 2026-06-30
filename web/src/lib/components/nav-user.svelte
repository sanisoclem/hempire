<script lang="ts">
  import * as Avatar from "$lib/components/ui/avatar/index.js";
  import * as DropdownMenu from "$lib/components/ui/dropdown-menu/index.js";
  import * as Sidebar from "$lib/components/ui/sidebar/index.js";
  import { useSidebar } from "$lib/components/ui/sidebar/index.js";
  import { usersCollection } from "$lib/collections";
  import { useLiveQuery } from "@tanstack/svelte-db";
  import ChevronsUpDownIcon from "@lucide/svelte/icons/chevrons-up-down";
  import LogOutIcon from "@lucide/svelte/icons/log-out";

  const sidebar = useSidebar();

  const userQuery = useLiveQuery((q) =>
    q
      .from({ u: usersCollection })
      .select(({ u }) => ({ friendly_name: u.friendly_name }))
      .findOne(),
  );

  const displayName = $derived(userQuery.data?.friendly_name ?? null);

  const initials = $derived(
    displayName
      ?.split(" ")
      .map((p) => p[0])
      .join("")
      .toUpperCase()
      .slice(0, 2) ?? "?",
  );
</script>

<Sidebar.Menu>
  <Sidebar.MenuItem>
    <DropdownMenu.Root>
      <DropdownMenu.Trigger>
        {#snippet child({ props })}
          <Sidebar.MenuButton
            size="lg"
            class="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
            {...props}
          >
            <Avatar.Root class="size-8 rounded-lg">
              <Avatar.Fallback class="rounded-lg text-xs"
                >{initials}</Avatar.Fallback
              >
            </Avatar.Root>
            <div class="grid flex-1 text-start text-sm leading-tight">
              <span class="truncate font-medium">{displayName}</span>
            </div>
            <ChevronsUpDownIcon class="ms-auto size-4" />
          </Sidebar.MenuButton>
        {/snippet}
      </DropdownMenu.Trigger>
      <DropdownMenu.Content
        class="w-(--bits-dropdown-menu-anchor-width) min-w-56 rounded-lg"
        side={sidebar.isMobile ? "bottom" : "right"}
        align="end"
        sideOffset={4}
      >
        <DropdownMenu.Label class="p-0 font-normal">
          <div class="flex items-center gap-2 px-1 py-1.5 text-start text-sm">
            <Avatar.Root class="size-8 rounded-lg">
              <Avatar.Fallback class="rounded-lg text-xs"
                >{initials}</Avatar.Fallback
              >
            </Avatar.Root>
            <span class="truncate font-medium">{displayName}</span>
          </div>
        </DropdownMenu.Label>
        <DropdownMenu.Separator />
        <form method="POST" action="/logout">
          <DropdownMenu.Item>
            {#snippet child({ props })}
              <button
                type="submit"
                class="flex w-full items-center gap-2"
                {...props}
              >
                <LogOutIcon class="size-4" />
                Log out
              </button>
            {/snippet}
          </DropdownMenu.Item>
        </form>
      </DropdownMenu.Content>
    </DropdownMenu.Root>
  </Sidebar.MenuItem>
</Sidebar.Menu>
