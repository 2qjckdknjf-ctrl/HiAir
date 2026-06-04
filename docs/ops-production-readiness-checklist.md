# Ops Production Readiness Checklist

## Deployment

- [x] Production workflow configured: `.github/workflows/backend-deploy-production.yml`
- [x] Staging deploy gate validated (GitHub Actions, 2026-06-04)
- [x] Production deploy gate validated (GitHub Actions run `26935841530`, 2026-06-04)
- [x] `DATABASE_URL`, `JWT_SECRET`, `NOTIFICATION_ADMIN_TOKEN`, `OPENAI_*`, `SUPABASE_*` in GitHub staging + production
- [ ] `HIAIR_DEPLOY_COMMAND` secret — **blocked on hosting choice** (repo has no Fly/Render/Dockerfile; gate runs verification-only until set)
- [ ] `HIAIR_ROLLBACK_COMMAND` secret — set with deploy command

## Observability

- [ ] `NOTIFICATION_ADMIN_TOKEN` distributed to on-call only
- [ ] `/api/observability/metrics` access validated from ops network
- [ ] Alerting policy configured for:
  - [ ] 5xx error spikes
  - [ ] latency degradation
  - [ ] auth failure spikes
  - [ ] webhook failures
- [ ] Incident owner and escalation rota documented

## Database Safety

- [ ] Backup schedule documented and active
- [ ] Restore drill executed successfully
- [x] Migration rollout tested on staging with current schema (Supabase `hiair-prod`, through `011_supabase_auth_user_fk_fixup`)
- [ ] Rollback strategy validated (app rollback + DB policy)

## AI / LLM Ops

- [x] `OPENAI_API_KEY` + `OPENAI_MODEL` in GitHub staging/production
- [x] Staging deploy smoke asserts `explanationSource=llm` when key set
- [x] `check_ai_connection.py --require-live` passes on staging deploy
- [x] Rate limits and token caps configured (`OPENAI_RATE_LIMIT_PER_MINUTE`, `OPENAI_MAX_TOKENS`)

## Release Governance

- [ ] External readiness strict check green:
  - `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`
- [ ] Sign-off check green:
  - `python3 scripts/release/check_signoff.py`
- [ ] Final gate executed:
  - `scripts/release/hiair_final_gate.sh --strict-external`
