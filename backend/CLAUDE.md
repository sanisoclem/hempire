# Hempire Backend

Haskell monorepo. Two Cabal packages per domain: `*-public` (types/API contract) and everything else split across `*-core`, `*-effects`, `*-interpreters`, `*-api`, etc.

## Build & verify

```bash
cabal build all        # must be zero warnings
cabal test all         # 19 tests: 5 hempire-public, 14 crm-core
hlint .                # must be zero hints
fourmolu --mode check $(find . -name "*.hs")
```

## Code conventions

- **No comments** in `.hs` files. Express intent in code; write prose in markdown. The only exception is `-- see: https://...` citation lines (e.g. the orphan-instance suppression in `Crm/Auth.hs`).
- **`fourmolu`** formats everything. Config at `backend/fourmolu.yaml`. Run `fourmolu --mode inplace` on any file you touch.
- **`hlint`** must pass clean. Fix suggestions; do not suppress unless genuinely wrong.
- **No orphan warnings** in Servant auth files — suppressed with `{-# OPTIONS_GHC -Wno-orphans #-}` per the Servant tutorial caveats.

## Effects (`effectful` v2.3)

- Effects live in `hempire-effects`. Interpreters live in `hempire-interpreters` or `*-interpreters`.
- `Dynamic` dispatch: `data Foo :: Effect where ...`, `type instance DispatchOf Foo = Dynamic`, `makeEffect ''Foo`.
- `runError @e` eliminates the effect (must be HEAD of stack). `tryError @e` catches within the same stack without eliminating.
- `Error CrmDomainError` is part of `CrmEffect es`. Domain errors **bubble** — handlers do not catch them. `appToHandler` catches at the HTTP boundary via `mapCrmError :: CrmDomainError -> Maybe CrmError` (`Nothing` → HTTP 500).

## ID generation

```haskell
iid :: InviteId   <- newId        -- generates a fresh prefixed ID
cid :: CustomerId <- deriveId iid -- deterministically derives one ID from another
```

GADT constructors are `NewIdRaw`/`DeriveIdRaw` (internal). Always use the typed wrappers.

## Environment variables

**All connection/infrastructure configs are required — no defaults.** The process fails immediately with a clear message if any are unset. Use `requireEnv` (defined locally in each loading function):

```haskell
requireEnv :: String -> IO String
requireEnv k = lookupEnv k >>= maybe (fail ("required env var not set: " <> k)) pure
```

Current required vars:

| Var | Used by |
|---|---|
| `CRM_DATABASE_URL` | `Crm.AppEnv` |
| `AUTH_JWKS_URI` | `crm-api` |
| `AUTH_ISSUER` | `crm-api` |
| `AUTH_AUDIENCE` | `crm-api` |
| `ZITADEL_API_URL` | `crm-api` |
| `ZITADEL_CLIENT_ID` | `crm-api` |
| `ZITADEL_CLIENT_SECRET` | `crm-api` |
| `AUTH_INTERNAL_JWKS_URI` | `crm-api-internal` |
| `AUTH_INTERNAL_ISSUER` | `crm-api-internal` |
| `AUTH_INTERNAL_AUDIENCE` | `crm-api-internal` |
| `CRM_AUTH_INTERNAL_REQUIRED_ROLE` | `crm-api-internal` |

Auth vars (`AUTH_*`) apply across all domains. DB vars are domain-prefixed (`CRM_DATABASE_URL`). See `.env.example` at the repo root.

## Domain error pattern

```
handler → throws CrmDomainError (bubbles)
appToHandler → runError @CrmDomainError → mapCrmError → HTTP response
```

Handlers only produce `Err` for their own business logic (e.g. "already onboarded"). They never catch domain errors.

## Infrastructure (local dev)

`docker-compose.yml` at repo root:
- **Postgres** on `5432` — databases: `crm` (default), `zitadel`, `zitadel_internal` (created by `docker/init-dbs.sh`)
- **Kafka** on `9092`
- **Zitadel** (customer) on `8081`
- **Zitadel** (internal) on `8082`

Recreate from scratch: `docker compose down -v && docker compose up -d`
