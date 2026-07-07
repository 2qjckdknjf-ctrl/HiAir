# HiAir — Rollback Guide

**Updated:** 2026-07-07

## Backend API (`api.hiair.io`)

### Option A — Redeploy previous commit (recommended)

1. Identify last known-good commit on `main` (e.g. `a2123fe`).
2. Re-run deploy workflow for that commit:
   - GitHub Actions → **Backend Deploy Production** → Run workflow on selected SHA, or
   - `git checkout <sha> && git push origin HEAD:main` (only if intentional rollback release).
3. Wait for container cold start (~1–3 min).
4. Verify: `.venv312/bin/python scripts/release/post_deploy_api_smoke.py`

### Option B — Cloudflare dashboard

1. Cloudflare dashboard → Workers & Pages → `hiair-api` worker.
2. Review deployment history; roll back to previous worker version if available.
3. Container image rollback may require redeploy from known-good git SHA.

### Option C — Disable broken route (emergency)

If a single endpoint is broken, hotfix forward is preferred over rollback.  
Privacy/auth regressions: revert commit and redeploy immediately.

## Web (`hiair.io`)

Cloudflare Pages → `hiair-web` → Deployments → Rollback to previous deployment.

Worker proxy (`hiair-io-proxy`): redeploy previous worker version via wrangler or GitHub workflow.

## Database (Supabase)

Schema rollback is **not automated**. Forward-fix migrations only.

Data restore: Supabase dashboard → Backups → Point-in-time recovery (operator action).

## Mobile clients

Already-shipped TestFlight/Play builds cannot be rolled back remotely.

- Ship hotfix build with incremented `versionCode` / build number.
- Backend must remain backward compatible for at least one prior mobile version during beta.

## Verification after rollback

```bash
curl -sS https://api.hiair.io/api/health
.venv312/bin/python scripts/release/post_deploy_api_smoke.py
bash scripts/release/hiair_final_gate.sh
```
