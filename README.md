# Hempire

B2B platform — CRM + double-entry ledger.

## Repository layout

```
backend/   Haskell — Cabal monorepo (6 packages)
web/       SvelteKit — BFF + frontend
docker/    Dockerfiles for the 4 Haskell binaries
```

---

## Prerequisites

### System packages (Arch Linux)

```bash
sudo pacman -S base-devel git curl pkgconf zlib openssl librdkafka docker docker-compose
```

`librdkafka` is a **hard requirement** for the Haskell build — `hw-kafka-client` is a C binding to it. If the build fails with a linker or C header error, this is almost certainly the cause.

Add yourself to the docker group, then re-login:

```bash
sudo usermod -aG docker $USER
sudo systemctl enable --now docker
```

### Haskell toolchain

Use `ghcup` — do **not** use the `ghc` package from Arch (it won't match the required version).

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
```

Then in a new shell:

```bash
ghcup install ghc 9.10.3
ghcup set ghc 9.10.3
ghcup install cabal 3.14.2
ghcup set cabal 3.14.2
ghcup install hls 2.13.0
ghcup set hls 2.13.0
```

Verify:

```bash
ghc --version    # The Glorious Glasgow Haskell Compilation System, version 9.10.3
cabal --version  # cabal-install version 3.14.2.0
```

### Bun (for the web app)

```bash
curl -fsSL https://bun.sh/install | bash
```

---

## Building the backend

```bash
cd backend
cabal update          # must run at least once to populate the package index
cabal build all
```

First build downloads and compiles all dependencies — this takes a while (10–20 min on a cold cache). Subsequent builds are incremental.

### Running a service locally

```bash
# Terminal 1 — start local Kafka + Postgres
docker compose up -d

# Terminal 2 — CRM API
cd backend
source ../.env.example
cabal run crm-api

# Terminal 3 — CRM worker
cd backend
source ../.env.example
cabal run crm-worker

# Terminal 4 — Ledger API
cd backend
source ../.env.example
cabal run ledger-api

# Terminal 5 — Ledger worker
cd backend
source ../.env.example
cabal run ledger-worker
```

Copy `.env.example` to `.env` and edit it if your local ports differ:

```bash
cp .env.example .env
```

---

## Building the web app

```bash
cd web
bun install
bun run dev      # development server with HMR
bun run build    # production build (adapter-node output in build/)
bun run check    # TypeScript + Svelte type-check
```

---

## Docker builds (production)

Each Haskell binary is compiled inside a `benz0li/ghc-musl` container (GHC + musl libc) and the result is a fully static binary copied into a `FROM scratch` image. Build context is the `backend/` directory.

```bash
docker build -f docker/crm-api.Dockerfile    backend/ -t crm-api
docker build -f docker/crm-worker.Dockerfile backend/ -t crm-worker
docker build -f docker/ledger-api.Dockerfile backend/ -t ledger-api
docker build -f docker/ledger-worker.Dockerfile backend/ -t ledger-worker
```

First Docker build is slow (~30 min) because it compiles GHC dependencies from scratch inside the container. Layer caching makes rebuilds fast — only changed packages recompile.

---

## Neovim / LazyVim

Enable the relevant extras (`:LazyExtras` or add to your config):

```lua
{ import = "lazyvim.plugins.extras.lang.haskell" },   -- haskell-tools.nvim + HLS
{ import = "lazyvim.plugins.extras.lang.svelte" },    -- svelte-language-server
{ import = "lazyvim.plugins.extras.lang.typescript" } -- ts_ls (for BFF routes)
```

HLS is picked up automatically once `ghcup install hls 2.13.0` has run. Open any `.hs` file from inside `backend/` — `haskell-tools.nvim` finds `cabal.project` automatically.

---

## Upgrading the toolchain

```bash
ghcup list                        # see available versions

ghcup install ghc   <new-version>
ghcup set     ghc   <new-version>
ghcup install hls   <new-version> # check haskell.org/ghcup for GHC↔HLS support matrix
ghcup set     hls   <new-version>
ghcup install cabal <new-version>
ghcup set     cabal <new-version>

cd backend && cabal update && cabal freeze
```

If GHC ships a new `base` version you may need to widen the `base ^>=4.20` bound in each `.cabal` file.

---

## Common build errors

### `Missing C library: rdkafka`

```
Error: Missing dependency on a foreign library:
* Missing (or bad) C library: rdkafka
```

Install `librdkafka`:

```bash
sudo pacman -S librdkafka
```

If Arch's package is too old for `hw-kafka-client`, build from the AUR instead:

```bash
yay -S librdkafka-git
```

### `Could not resolve dependencies` / solver timeout

Run `cabal update` first, then retry. If it still fails, try removing the freeze file and rebuilding:

```bash
rm -f backend/cabal.project.freeze
cabal update && cabal build all
```

### `GHC2024` or `base` version errors

You are not on GHC 9.10.3. Check with `ghc --version` and switch with `ghcup set ghc 9.10.3`.

### HLS not starting in Neovim

Run `:checkhealth haskell-tools` inside Neovim. The most common cause is HLS not being on `$PATH` — confirm with:

```bash
which haskell-language-server-wrapper
```

If missing, run `ghcup install hls 2.13.0` and restart Neovim.
