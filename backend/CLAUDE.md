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
- `Error HempireInternalError` wraps infrastructure failures (`DatabaseErr`, `DecodeErr`). It sits at the outermost layer of the effect stack (outside `runDatabasePostgres`). On `Left`, `appToHandler` logs and returns HTTP 500.
- `WithTransactionRollback` is the `Database` effect operation for actions that return `Either e a` — it calls `PG.rollback` explicitly on `Left` (vs `PG.withTransaction` which relies on exception propagation). Use it when the action returns an explicit `Either`; use `withTransaction` for effect-stack-based error propagation.

## ID generation

```haskell
iid :: InviteId   <- newId        -- generates a fresh prefixed ID
cid :: CustomerId <- deriveId iid -- deterministically derives one ID from another
```

GADT constructors are `NewIdRaw`/`DeriveIdRaw` (internal). Always use the typed wrappers.

## Environment variables

**All connection/infrastructure configs are required — no defaults.** Use `requireEnv` from `Hempire.Env` (in `hempire-public`). The process fails immediately with a clear message if any are unset.

Naming rule: prefix must be a domain name (`CRM_`), `BACKEND_`, or `BFF_`. `CRM_` scopes to the CRM domain; `BACKEND_` for cross-domain backend infra.

Current required vars:

| Var | Used by |
|---|---|
| `CRM_DATABASE_URL` | `Crm.AppEnv` |
| `CRM_AUTH_JWKS_URI` | `crm-api` |
| `CRM_AUTH_ISSUER` | `crm-api` |
| `CRM_AUTH_AUDIENCE` | `crm-api` |
| `CRM_ZITADEL_API_URL` | `crm-api` |
| `CRM_ZITADEL_CLIENT_ID` | `crm-api` |
| `CRM_ZITADEL_CLIENT_SECRET` | `crm-api` |
| `CRM_AUTH_INTERNAL_JWKS_URI` | `crm-api-internal` |
| `CRM_AUTH_INTERNAL_ISSUER` | `crm-api-internal` |
| `CRM_AUTH_INTERNAL_AUDIENCE` | `crm-api-internal` |
| `CRM_AUTH_INTERNAL_REQUIRED_ROLE` | `crm-api-internal` |
| `CRM_API_PORT` | `crm-api` |
| `CRM_API_INTERNAL_PORT` | `crm-api-internal` |
| `BACKEND_KAFKA_BROKERS` | `outbox-sender` |
| `BACKEND_OUTBOX_DATABASE_URLS` | `outbox-sender` |
| `BACKEND_REDIS_URL` | `Hempire.AppEnv` (passed as `redis://host:port`) |

See `.env.example` at the repo root.

## Caching (`Cache` effect)

- Effect: `Hempire.Effect.Cache` — `getCached`, `setCached`, `invalidateCache`, plus JSON helpers `getCachedJson` / `setCachedJson`.
- Redis interpreter: `Hempire.Interpreter.Cache.Redis.runCacheRedis :: Connection -> Eff (Cache : es) a -> Eff es a`
- Mock interpreter: `Hempire.Interpreter.Cache.Mock.runCacheMock :: TVar (Map Text ByteString) -> Eff (Cache : es) a -> Eff es a`
- Redis connection is created in `Hempire.AppEnv` (reads `BACKEND_REDIS_URL`), stored as `appRedis :: R.Connection`.
- **Caching is a repository concern, not a core concern.** Interpreters may cache; core business logic must not know about it.

## Domain error pattern

```
handler → throws CrmDomainError (bubbles)
appToHandler → runError @CrmDomainError → mapCrmError → HTTP response
              runError @HempireInternalError → log + HTTP 500
```

Handlers only produce `Err` for their own business logic. They never catch infrastructure errors.

## Infrastructure (local dev)

`docker-compose.yml` at repo root:
- **Postgres** on `5432` — databases: `crm` (default), `zitadel`, `zitadel_internal` (created by `docker/init-dbs.sh`)
- **Kafka** on `9092`
- **Redis** on `6379`
- **Zitadel** (customer) on `8081`
- **Zitadel** (internal) on `8082`

Recreate from scratch: `docker compose down -v && docker compose up -d`
