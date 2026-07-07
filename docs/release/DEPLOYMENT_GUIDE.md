# HiAir — Deployment Guide

**Updated:** 2026-07-07  
**Production API:** `https://api.hiair.io`  
**Production web:** `https://hiair.io`

## Backend (Cloudflare Containers)

Automated via GitHub Actions on push to `main`:

- Workflow: `.github/workflows/backend-deploy-production.yml`
- Deploy script: `scripts/ops/deploy_hiair_api_cloudflare.sh`
- Worker: `infra/cloudflare/hiair-api/`

### Pre-deploy validation (local)

```bash
PYTHONPATH=backend .venv312/bin/pytest backend/tests --no-cov -q
cd backend && HIAIR_GATE_PYTHON=../.venv312/bin/python ./run_gate.sh --skip-db
```

### Post-deploy smoke

```bash
.venv312/bin/python scripts/release/post_deploy_api_smoke.py
```

Checks: health, environment sample, privacy export (401 not 402).

### Manual deploy (requires Docker + wrangler login)

```bash
HIAIR_API_ENV_FILE=backend/.env.local ./scripts/ops/deploy_hiair_api_cloudflare.sh
```

## Web (Cloudflare Pages + Worker proxy)

```bash
./scripts/ops/connect_hiair_io.sh
```

Static site: `web/` → Cloudflare Pages project `hiair-web`.  
API proxy: `infra/cloudflare/hiair-io-proxy/`.

## Mobile release builds

| Platform | Release API | Command |
|----------|-------------|---------|
| Android | `https://api.hiair.io` | `cd mobile/android && ./gradlew :app:assembleRelease` |
| iOS | `https://api.hiair.io` | Xcode Release scheme or `xcodebuild -configuration Release` |

Debug builds use localhost only (`10.0.2.2:8000` / `127.0.0.1:8000`).

## Supabase migrations

Migrations: `backend/sql/*.sql`  
Apply via Supabase MCP or operator runbooks under `docs/_operator/`.

## Secrets

- Local: `backend/.env.local` (gitignored)
- GitHub production env: synced via `scripts/release/sync_github_env_secrets.py`
- Never commit: `.p8`, service role keys, review passwords
