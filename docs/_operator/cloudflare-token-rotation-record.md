# Cloudflare deploy token rotation record

Date: 2026-07-20  
Account ID: `864f04d729c24f574a228558b40d7b82`  
Target secret: GitHub Environment `production` / `CLOUDFLARE_API_TOKEN` only

## Investigation (complete)

| Source | Result |
|--------|--------|
| `~/.wrangler`, `~/.config/wrangler`, `~/.cloudflare` | Missing |
| `~/Library/Preferences/.wrangler/config/default.toml` | Present — OAuth `oauth_token` + `refresh_token` (expired access, refresh recoverable) |
| macOS Keychain (Cloudflare/Wrangler/dash/api) | No deployable API token (only unrelated NetworkServiceProxy entry) |
| `backend/.env.local` | No `CLOUDFLARE_*` keys |
| Other project secret files | No reusable CF deploy token |
| GitHub repo secrets | Empty |
| GitHub `production` env secrets | `CLOUDFLARE_API_TOKEN` exists (was stale OAuth synced 2026-07-14) |
| Last successful deploy `29310207000` | Used OAuth (`cloudflare-token: OK oauth functional check`) |
| Failed deploys `29684191710` / `29684194650` | Preflight 403 / code 1000 Invalid API Token |

## Recovery method

| Item | Result |
|------|--------|
| Credential source | Wrangler OAuth **refresh_token** (local config) |
| Refresh endpoint | `https://dash.cloudflare.com/oauth2/token` |
| Client ID | Wrangler public client `54d11594-84e4-41aa-b438-e81b8fa78ee7` |
| Functional checks | `GET /accounts` 200; `GET …/workers/scripts/hiair-api` 200 |
| Local secret file | Written `backend/.secrets/cloudflare_api_token` (chmod 600, gitignored) — value never logged |
| GitHub secret update | `production/CLOUDFLARE_API_TOKEN` updated 2026-07-20T18:17:12Z |

## 2026-08-22 rotation (feat/hiair-1.2-best-time-planner deploy)

| Item | Result |
|------|--------|
| Symptom | `Backend Deploy Production` failed at **Verify Cloudflare deploy token** (403 / code 1000) |
| Recovery | `refresh_wrangler_oauth.py --write-secret-file` + `gh secret set CLOUDFLARE_API_TOKEN --env production` |
| Deploy run | `32564334495` — PASS (post-deploy smoke + `deploy_git_sha=1e1230d5…`) |
| Follow-up | Create long-lived **Custom API Token** per runbook — OAuth access tokens expire (~1h) |
| Preflight | `cloudflare-deploy-preflight: PASS` (oauth functional check) |
| Helper added | `scripts/ops/refresh_wrangler_oauth.py` + rotate script auto-refresh fallback |

Token value is never written to this record.

## Deploy after rotation

| Item | Result |
|------|--------|
| Run | https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/29767120259 |
| Source SHA | `56393407056e4ef7adbaace9b71b06c9860ad93f` |
| Image tag | `hiair-api-hiairapicontainer:6d88b1b8` |
| Workflow | success |
| `deploy_git_sha` | `56393407056e4ef7adbaace9b71b06c9860ad93f` |

## Note

Prefer a long-lived **Custom API Token** for CI stability. OAuth refresh works and was proven sufficient for this recovery; expires ~16h and should be refreshed before the next deploy if Custom Token is still unavailable.

## Stage 0 recovery (2026-07-23)

| Item | Result |
|------|--------|
| Failure | Deploy `30014901323` — Verify Cloudflare deploy token → 403 / code 1000 |
| Recovery | `python3 scripts/ops/rotate_cloudflare_github_token.py` (Wrangler OAuth refresh → GitHub `production/CLOUDFLARE_API_TOKEN`) |
| Follow-on bug | Secrets writer indentation caused incomplete secret sync; warm container kept stale `DEPLOY_GIT_SHA` |
| Fix commit | `0243952` — full secret sync + SHA-pinned container instance + smoke `--expect-sha` |
| Successful deploy | https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/30015917425 |
| Live SHA | `02439521f3c56eb7ebe0fe6119d0be2179138293` |

