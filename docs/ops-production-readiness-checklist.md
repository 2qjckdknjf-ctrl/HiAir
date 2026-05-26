# Ops Production Readiness Checklist

## Deployment

- [ ] Production workflow configured: `.github/workflows/backend-deploy-production.yml`
- [ ] `HIAIR_DEPLOY_COMMAND` secret configured in production environment
- [ ] `HIAIR_ROLLBACK_COMMAND` secret configured in production environment
- [ ] `DATABASE_URL`, `JWT_SECRET`, `NOTIFICATION_ADMIN_TOKEN` configured

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
- [ ] Migration rollout tested on staging with current schema
- [ ] Rollback strategy validated (app rollback + DB policy)

## Release Governance

- [ ] External readiness strict check green:
  - `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`
- [ ] Sign-off check green:
  - `python3 scripts/release/check_signoff.py`
- [ ] Final gate executed:
  - `scripts/release/hiair_final_gate.sh --strict-external`
