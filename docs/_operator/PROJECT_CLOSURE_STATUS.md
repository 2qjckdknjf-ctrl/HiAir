# HiAir Project Closure Status

**Updated:** 2026-06-17  
**Branch:** `main`  
**Scope:** engineering closure vs public launch closure

---

## Executive summary

| Lane | Status | Notes |
|------|--------|-------|
| **Backend / API / AI** | **CLOSED** | Live `https://api.hiair.io`, LLM observability green, production deploy workflow green |
| **Supabase DB** | **CLOSED (engineering)** | Migrations through `017_rls_subscription_waitlist_lockdown`; security advisor ERRORs on public RLS resolved |
| **CI / deploy automation** | **CLOSED** | Staging + production gates, Cloudflare container deploy, GitHub secrets synced |
| **Public store launch** | **OPEN** | EXT-001…005 ledger, device QA, sign-off, sandbox IAP |
| **Mobile QA on hardware** | **OPEN** | `REAL_DEVICE_QA_REPORT.md` — all rows BLOCKED (owner session required) |

---

## Closed (engineering)

- Production API deploy: `backend-deploy-production.yml` + `hiair-api-cloudflare.yml`
- GitHub secrets: `DATABASE_URL`, `OPENAI_*`, `SUPABASE_*`, `CLOUDFLARE_*` (staging + production)
- AI module: LEVEL 5 — `check_ai_connection --require-live`, `post_deploy_api_smoke --require-live-ai`
- Supabase `hiair-prod`: migrations `001`–`011`, `013`, `014`, `016`, **`017`** (RLS for subscription/waitlist tables)
- External credentials strict check: env + store artifacts + legal URLs (`check_external_readiness.py --strict`)
- Backend CI green on GitHub; iOS simulator Release build passes locally

---

## Open — P0 (cannot close without owner / hardware / store consoles)

| ID | Item | Owner | Evidence to close |
|----|------|-------|-------------------|
| EXT-001 | TestFlight upload | Product/Founder | [#2](https://github.com/2qjckdknjf-ctrl/HiAir/issues/2) + upload screenshot |
| EXT-002 | Play internal track | Product/Founder | [#3](https://github.com/2qjckdknjf-ctrl/HiAir/issues/3) + AAB release |
| EXT-003 | Legal final signoff | Legal | [#4](https://github.com/2qjckdknjf-ctrl/HiAir/issues/4) |
| EXT-004 | Secrets governance record | Security/Ops | [#5](https://github.com/2qjckdknjf-ctrl/HiAir/issues/5) |
| EXT-005 | Store metadata completion | Product/Marketing | [#6](https://github.com/2qjckdknjf-ctrl/HiAir/issues/6) |
| QA-001 | Real device QA matrix | Mobile QA | Fill `docs/release/qa/REAL_DEVICE_QA_REPORT.md` with PASS + evidence |
| SIG-001 | Release sign-off | All leads | Set `DONE` in `docs/_operator/release-signoff-template.md` |
| AUTH-001 | Supabase Google/Apple OAuth | Ops | Dashboard + `scripts/ops/configure_supabase_*.py` (needs `SUPABASE_ACCESS_TOKEN` PAT) |
| IAP-001 | Store sandbox purchases | Mobile + Backend | `SUBSCRIPTION_QA_CHECKLIST.md`; set verifier modes `live` before prod IAP |

---

## Open — P1 (ops hardening)

| Item | Notes |
|------|-------|
| `CLOUDFLARE_API_TOKEN` rotation | Current token is wrangler OAuth (~expires); replace with Custom API Token in GitHub |
| `SUPABASE_ACCESS_TOKEN` | Account PAT for Management API (redirect URLs, OAuth providers) — not in `~/.config/hiair/supabase-credentials.env` |
| Observability alerting | 5xx/latency/auth/webhook alerts + on-call rota (`docs/ops-production-readiness-checklist.md`) |
| DB backup / restore drill | Document + execute restore test on `hiair-prod` |
| `NOTIFICATIONS_PROVIDER_MODE` | Production deploy defaults to stub unless wired in Cloudflare secrets |
| Local dev toolchain | `backend/.venv` x86 on arm64 Mac; install arm64 Python 3.12+ venv for local pytest |

---

## Gate commands (current expected results)

```bash
# Engineering green
python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local
# → FAIL (REAL_DEVICE_QA_EXECUTION BLOCKED) — expected until device QA

python3 scripts/release/check_signoff.py
# → FAIL (all roles PENDING) — expected until owners sign

scripts/release/hiair_final_gate.sh --strict-external
# → FAIL on strict external until QA BLOCKED; Android skipped locally without Java

# Production smoke (with local .env.local)
python3 scripts/release/post_deploy_api_smoke.py --require-live-ai
# → PASS
```

---

## Next actions (recommended order)

1. Mobile QA owner: execute device matrix → update QA report → re-run strict external check.
2. Product: close EXT-001/002 with store uploads.
3. Ops: create long-lived Cloudflare API token; optional `SUPABASE_ACCESS_TOKEN` PAT for auth redirect/OAuth scripts.
4. All leads: complete `release-signoff-template.md`.
5. Run `scripts/release/hiair_final_gate.sh --strict-external` after QA + sign-off for full launch green.
