# Hempire

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

### Running a service locally

TODO: use telepresence

---

## Building the web app

```bash
cd web
bun install
bun run dev      # development server with HMR
bun run build    # production build (adapter-node output in build/)
bun run check    # TypeScript + Svelte type-check
```
