# HiAir External Blocker Dashboard

Last updated: 2026-04-22

Live tracking dashboard for release-blocking non-code dependencies.

| ID | Issue | Status | Assignee | Target date | Last update (UTC) | Immediate next action |
|---|---|---|---|---|---|---|
| EXT-001 | [#2](https://github.com/2qjckdknjf-ctrl/HiAir/issues/2) | OPEN | 2qjckdknjf-ctrl | 2026-04-29 | 2026-04-22T06:59:00Z | Confirm App Store Connect access and attach evidence in issue thread |
| EXT-002 | [#3](https://github.com/2qjckdknjf-ctrl/HiAir/issues/3) | OPEN | 2qjckdknjf-ctrl | 2026-04-29 | 2026-04-22T06:59:02Z | Confirm Play Console access and attach internal track upload evidence |
| EXT-003 | [#4](https://github.com/2qjckdknjf-ctrl/HiAir/issues/4) | OPEN | 2qjckdknjf-ctrl | 2026-04-29 | 2026-04-22T06:59:04Z | Confirm legal owner and attach signoff artifact + final policy URLs |
| EXT-004 | [#5](https://github.com/2qjckdknjf-ctrl/HiAir/issues/5) | OPEN | 2qjckdknjf-ctrl | 2026-04-29 | 2026-04-22T06:59:06Z | Confirm security/ops owner and attach secrets governance approval |
| EXT-005 | [#6](https://github.com/2qjckdknjf-ctrl/HiAir/issues/6) | OPEN | 2qjckdknjf-ctrl | 2026-04-29 | 2026-04-22T06:59:08Z | Attach finalized store metadata packet and compliance evidence |

## Execution policy

- Treat all rows as release blockers until issue is closed with evidence.
- Daily cadence: review issue updates, enforce owner assignment, and move stale blockers.
- Escalation trigger: any blocker without owner or target date for >48h.
- Daily update template: `docs/_operator/daily-external-blocker-template.md`
- Escalation matrix: `docs/_operator/external-blocker-escalation-matrix.md`
- Latest daily update: `docs/_operator/daily-external-blocker-update-2026-04-22.md`

## Automation

Recommended one-command pipeline:

```bash
python3 backend/scripts/run_external_blocker_ops.py
```

Manual step-by-step (if needed):

```bash
python3 backend/scripts/generate_daily_external_blocker_update.py
python3 backend/scripts/refresh_external_blocker_dashboard.py
python3 backend/scripts/check_external_blocker_escalations.py
```
