# Ops Production Readiness Checklist

## Deployment

- [x] Production workflow configured: `.github/workflows/backend-deploy-production.yml` (DB/AI gate + Cloudflare + API smoke)
- [x] Staging deploy gate validated (GitHub Actions, 2026-06-04)
- [x] Production deploy gate validated (GitHub Actions run `26935841530`, 2026-06-04)
- [x] Live API health + AI observability on `https://api.hiair.io` (`post_deploy_api_smoke.py --require-live-ai`)
- [x] `DATABASE_URL`, `JWT_SECRET`, `NOTIFICATION_ADMIN_TOKEN`, `OPENAI_*`, `SUPABASE_*` in GitHub staging + production
- [x] `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` in GitHub production (enables auto container deploy in workflow)
- [x] `HIAIR_DEPLOY_COMMAND` / `HIAIR_ROLLBACK_COMMAND` — optional; production uses built-in Cloudflare deploy step (legacy secret may remain in GitHub)

## Observability

- [ ] `NOTIFICATION_ADMIN_TOKEN` distributed to on-call only
- [x] `/api/observability/ai-summary` validated on production API
- [x] `/api/observability/metrics` access validated from ops network (2026-06-17, admin token)
- [ ] Alerting policy configured for:
  - [ ] 5xx error spikes
  - [ ] latency degradation
  - [ ] auth failure spikes
  - [ ] webhook failures
- [ ] Incident owner and escalation rota documented

## Database Safety

- [ ] Backup schedule documented and active
- [ ] Restore drill executed successfully
- [x] Migration rollout tested on staging with current schema (Supabase `hiair-prod`, through `017_rls_subscription_waitlist_lockdown`)
- [ ] Rollback strategy validated (app rollback + DB policy)

## AI / LLM Ops

- [x] `OPENAI_API_KEY` + `OPENAI_MODEL` in GitHub staging/production
- [x] Staging deploy smoke asserts `explanationSource=llm` when key set
- [x] `check_ai_connection.py --require-live` passes on staging/production deploy gates
- [x] Production API reports live LLM (`provider_configured`, `llm_success_count>=1`)
- [x] Rate limits and token caps configured (`OPENAI_RATE_LIMIT_PER_MINUTE`, `OPENAI_MAX_TOKENS`)

## Release Governance

- [x] External readiness strict check (credentials + artifacts): `check_external_readiness.py --strict` — **BLOCKED on device QA execution** until `REAL_DEVICE_QA_REPORT.md` has PASS rows
- [ ] Sign-off check green: `python3 scripts/release/check_signoff.py`
- [ ] Final gate full green: `scripts/release/hiair_final_gate.sh --strict-external` (after QA + sign-off)
- [ ] Closure tracker reviewed: `docs/_operator/PROJECT_CLOSURE_STATUS.md`
