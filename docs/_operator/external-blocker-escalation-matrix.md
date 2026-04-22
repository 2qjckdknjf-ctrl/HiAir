# External Blocker Escalation Matrix

Last updated: 2026-04-21

This matrix defines when and how to escalate unresolved release blockers.

| Condition | Time threshold | Escalation action | Target |
|---|---|---|---|
| Blocker has no owner | >48h | Post escalation comment in blocker issue and in #7 | Product/Founder |
| Blocker has no target date | >48h | Require due date commitment in issue thread | Blocker owner |
| Blocker has no status update | >72h | Mark as stalled in dashboard and request update | Blocker owner |
| Blocker misses committed target date | immediately | Raise severity in #7 and request recovery plan in 24h | Product + owner |
| Legal/platform dependency uncertain | >5 days | Add explicit risk note to go/no-go verdict and weekly snapshot | Release manager |

## Execution loop

1. Run daily update using `daily-external-blocker-template.md`.
2. Update `external-blocker-dashboard.md` if status/owner/date changed.
3. If any threshold breached, escalate per matrix and log it in #7.
