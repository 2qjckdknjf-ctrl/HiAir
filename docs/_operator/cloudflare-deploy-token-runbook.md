# Cloudflare Deploy Token Runbook (HiAir API)

**Symptom:** GitHub Actions `Deploy API to Cloudflare Containers` fails with:

- `Authentication error [code: 10000]` on `secrets-bulk`
- `Invalid access token [code: 9109]`

**Root cause:** `CLOUDFLARE_API_TOKEN` in GitHub **production** environment is expired or invalid (common when a short-lived **wrangler OAuth** token was synced).

Last successful deploy: run `28872808828` (2026-07-07). Failed runs: `29072333018`, `29072760859`.

---

## Required token type

Create a **Custom API Token** (long-lived), not wrangler OAuth.

### Permissions (minimum)

| Resource | Permission |
|----------|------------|
| Account → Workers Scripts | **Edit** |
| Account → Workers Scripts | **Secrets** (if listed separately) |
| Account → Workers Containers | **Edit** (if available) |
| Account | **Read** |
| Zone (optional) | Read (if wrangler requests zone scope) |

Template: use Cloudflare dashboard → **My Profile → API Tokens → Create Token → Edit Cloudflare Workers** and extend with Containers if offered.

---

## Steps

1. Cloudflare Dashboard → API Tokens → **Create Custom Token**
2. Name: `hiair-github-production-deploy`
3. Account resources: include HiAir account (`CLOUDFLARE_ACCOUNT_ID` in GitHub secrets)
4. Save token (shown once)

5. GitHub → `2qjckdknjf-ctrl/HiAir` → **Settings → Environments → production → Secrets**
6. Update **`CLOUDFLARE_API_TOKEN`** with the new custom token
7. Confirm **`CLOUDFLARE_ACCOUNT_ID`** is set

8. Local preflight (optional, do not print token). Prefer the secret file — verify/rotate
   read `backend/.secrets/cloudflare_api_token` before any shell env (avoids stale OAuth):

```bash
# after create_cloudflare_custom_deploy_token.py OR manual paste into the secret file:
python3 scripts/ops/verify_cloudflare_deploy_token.py
python3 scripts/ops/rotate_cloudflare_github_token.py
```

9. Re-run workflow: **Actions → Backend Deploy Production → Run workflow** on `main`

---

## Success criteria

- Workflow step **Verify Cloudflare deploy token** → PASS
- **Deploy API to Cloudflare Containers** → PASS
- **Post-deploy API smoke** → PASS
- `GET https://api.hiair.io/api/health` includes `deploy_git_sha` matching deployed commit

---

## Do not

- Disable post-deploy smoke
- Skip secret bulk with `|| true`
- Commit tokens to the repository
- Use expired wrangler OAuth from `~/.wrangler/config/default.toml` in CI

---

## Sync helper (after `wrangler login` OR custom token in `.env.local`)

```bash
# Only if backend/.env.local has valid CLOUDFLARE_API_TOKEN=
python3 scripts/release/sync_github_env_secrets.py \
  --env-file backend/.env.local \
  --environment production \
  --refresh-cloudflare-oauth
```

Prefer **custom token in `.env.local`** over OAuth refresh for production stability.


## Automated Custom Token (preferred)

1. In Cloudflare Dashboard create a one-time **Create Additional Tokens** bootstrap token.
2. Locally:

```bash
export CLOUDFLARE_BOOTSTRAP_TOKEN='...'
export CLOUDFLARE_ACCOUNT_ID='864f04d729c24f574a228558b40d7b82'
python3 scripts/ops/create_cloudflare_custom_deploy_token.py
python3 scripts/ops/rotate_cloudflare_github_token.py
python3 scripts/ops/verify_cloudflare_deploy_token.py
```

3. Revoke the bootstrap token after the long-lived deploy token is verified.
