# HiAir Incident Response Runbook (Beta)

Last updated: 2026-04-18

This runbook defines minimum steps for backend/mobile beta incidents.

## Severity model

- **P0**: complete outage, data loss, or active security exposure.
- **P1**: major user-visible degradation in core flows.
- **P2**: partial degradation or non-core failures with workaround.

## First 15 minutes

1. Declare incident in ops channel and assign incident commander.
2. Capture UTC start time and suspected impact scope.
3. Freeze non-essential deployments and migrations.
4. Run quick checks:
   - `/api/health`
   - `/api/observability/metrics` (with `X-Admin-Token` when configured)
   - `/api/notifications/provider-health` (with `X-Admin-Token` when configured)
5. Confirm whether issue is reproducible in:
   - API only
   - iOS only
   - Android only
   - cross-platform

## Triage checklist

- Auth/session failures:
  - verify `JWT_SECRET` consistency and token issuance path
  - verify DB availability
- Subscription/webhook anomalies:
  - verify `SUBSCRIPTION_WEBHOOK_SECRET`
  - inspect recent webhook event patterns
- Notification delivery failures:
  - verify credentials health and provider mode
  - inspect delivery attempts endpoint
- Privacy/export/delete failures:
  - run focused DB checks and inspect recent schema changes

## Containment options

- Disable unstable feature flags or automation jobs.
- Switch to safe fallback behavior where available.
- Restrict external access to affected surfaces.
- Communicate temporary user guidance for beta testers.

## Recovery validation

After fix rollout, run:

```bash
cd backend
../.venv/bin/python -m pytest tests -q
../.venv/bin/python scripts/validate_risk_historical.py
../.venv/bin/python scripts/beta_preflight.py --base-url "$BASE_URL" --admin-token "$NOTIFICATION_ADMIN_TOKEN"
```

For DB-related incidents also run:

```bash
cd backend
../.venv/bin/python scripts/smoke_db_flow.py
```

## Exit criteria

- Monitoring checks stable for agreed observation window.
- Core beta flows verified manually on both mobile clients.
- Incident timeline and root cause recorded.
- Follow-up preventive actions captured with owner/date.

## Post-incident template

- Incident ID:
- Start/End time (UTC):
- Severity:
- User impact summary:
- Root cause:
- Immediate fix:
- Preventive actions:
- Owner + due dates:
