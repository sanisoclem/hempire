# Zitadel Setup

Open <http://localhost:8081/ui/console>.

Default initial admin credentials (set by `start-from-init`):

| Field    | Value                             |
|----------|-----------------------------------|
| Username | `zitadel-admin@zitadel.localhost` |
| Password | `Password1!`                      |

---

**Application** — an OAuth2 client inside a project.

**Service User** — a machine account at the org level, separate from any project. Used by `crm-api` to call Zitadel's own management API after onboarding.

---

## 1. Create the `Hempire` project

1. **Projects → New Project**, name it `Hempire`.
2. Note the **Resource ID** shown on the project's General page — this is your `BFF_AUDIENCE`.

### Add the customer BFF application

1. **Applications → New**, type **Web**, name it `hempire-bff`.
2. Auth method: **PKCE**.
3. Redirect URIs: `http://localhost:3000/auth/callback`.
4. Save. Note the **Client ID** (needed by the SvelteKit BFF).
5. Open the app → **Token Settings** → Access token type: **JWT**.

### Add `crm-api` as a resource

1. **Applications → New**, type **API**, name it `crm-api`.
2. Auth method: **Basic**.
3. Save. Note the **Client ID** and generate a **Client Secret**.
   *(These aren't used to call `crm-api` — they're what a caller would use if calling Zitadel on behalf of this resource. In practice you mainly need the application to exist so `crm-api` appears as a valid audience in `Hempire` tokens.)*

---

## 2. Create the `Hempire Internal` project

1. **Projects → New Project**, name it `Hempire Internal`.
2. Note the **Resource ID** — this is your `INTERNAL_AUDIENCE`.

### Add the admin portal application (employees)

1. **Applications → New**, type **Web**, name it `hempire-admin`.
2. Auth method: **PKCE**.
3. Redirect URIs: `http://localhost:3001/auth/callback` (adjust as needed).
4. Save. Note the **Client ID**.
5. Open the app → **Token Settings** → Access token type: **JWT**.

### Add `crm-api` as a resource

1. **Applications → New**, type **API**, name it `crm-api`.
2. Auth method: **Basic**.
3. Save. Note the **Client ID** and generate a **Client Secret** — internal services use these to get a token scoped to `Hempire Internal`.

---

## 3. Create the service user for `crm-api`

`crm-api` calls Zitadel's management API after onboarding to write `customer_id` metadata onto the user. This uses a dedicated org-level service user — not an application in either project.

1. **Organisation → Service Users → New**, username: `crm-api-service`.
2. Open the service user → **Client Secrets → New Secret**. Copy the secret.
   Note the service user's **Client ID** (shown on the detail page).
3. Grant it org-level permission to write metadata:
   - **Organisation → Members → Add** → search `crm-api-service` → role **Org Owner**.
   - (Production: scope to a custom role with only `UserMetadata.Write`.)
4. Copy into `.env`:

```env
ZITADEL_CLIENT_ID=<crm-api-service client id>
ZITADEL_CLIENT_SECRET=<crm-api-service client secret>
```

---

## 4. Create the `projectCustomerId` Action

After a user is onboarded, `crm-api` writes their `customer_id` as Zitadel user metadata (base64-encoded). This Action reads that metadata and injects it as `https://hempire.com/customer_id` into every access token, so `crm-api` can read the customer ID directly from the JWT without a database lookup.

The Action is a no-op for employees and service accounts because they won't have `customer_id` metadata.

1. **Instance → Actions → New Action**, name it `projectCustomerId`.
2. Paste:

```javascript
function projectCustomerId(ctx, api) {
  var meta = ctx.v1.user.metadata;
  if (!meta) return;

  for (var i = 0; i < meta.length; i++) {
    if (meta[i].key === "customer_id") {
      // Zitadel stores metadata values as base64
      var decoded = String.fromCharCode.apply(
        null,
        Array.from(atob(meta[i].value)).map(function(c) { return c.charCodeAt(0); })
      );
      api.v1.claims.setClaim("https://hempire.com/customer_id", decoded);
      return;
    }
  }
}
```

3. Timeout: `5s`. Save.
4. **Flows → Complement Token → Add Trigger**:
   - Trigger **Pre Access Token Creation** → `projectCustomerId`
   - Trigger **Pre Userinfo Creation** → `projectCustomerId`

---

## 5. Seed the identity provider record

`crm-api` looks up IdP config by `IdentityProviderId` before onboarding. Insert the Zitadel row after running migrations:

```bash
psql postgres://hempire:hempire@localhost:5432/hempire_bff \
  -c "INSERT INTO identity_providers (identity_provider_id, idp_type, enable_customers)
      VALUES ('idp_zitadel', 'zitadel', true);"
```

The `providerId` in the `OnboardCustomer` request must be `idp_zitadel`. The `identityId` field is the user's Zitadel user ID (the `sub` claim).

---

## 6. Fill in `.env`

```env
# Service user — used by crm-api to call Zitadel management API
ZITADEL_API_URL=http://localhost:8081
ZITADEL_CLIENT_ID=<crm-api-service client id>
ZITADEL_CLIENT_SECRET=<crm-api-service client secret>

# JWT auth — Resource IDs from Project → General in the console
BFF_AUDIENCE=<Hempire Resource ID>
BFF_ISSUER=http://localhost:8081
BFF_JWKS_URI=http://localhost:8081/oauth/v2/keys
INTERNAL_AUDIENCE=<Hempire Internal Resource ID>
INTERNAL_ISSUER=http://localhost:8081
INTERNAL_JWKS_URI=http://localhost:8081/oauth/v2/keys
```

For production, replace `http://localhost:8081` with the public Zitadel domain throughout.

---

## Verification

```bash
# Get an internal token (service account in Hempire Internal)
TOKEN=$(curl -s -X POST http://localhost:8081/oauth/v2/token \
  -d "grant_type=client_credentials" \
  -d "client_id=<crm-api client id from Hempire Internal>" \
  -d "client_secret=<client secret>" \
  -d "scope=openid" | jq -r .access_token)

# Decode and confirm aud matches Hempire Internal Resource ID
echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | jq .aud

# Call crm-api — should get InternalAuth
curl -s http://localhost:8080/invites/<invite-id> \
  -H "Authorization: Bearer $TOKEN" | jq .
```
