# Closed Beta Ops Runbook

Status: READY_FOR_OWNER

## Ownership

- Beta owner: BLOCKED_EXTERNAL: owner assignment required
- On-call owner: BLOCKED_EXTERNAL: owner assignment required
- Support contact: BLOCKED_EXTERNAL: support channel required

## Incident Severity

- P0: data loss, auth/privacy exposure, app unusable for most testers.
- P1: core flow broken for a platform, notification storm, backend outage.
- P2: degraded feature, intermittent API errors, isolated tester reports.

## Rollback Triggers

- P0 incident.
- Failed auth/privacy/export/delete behavior.
- Push notification spam or incorrect high-risk alerts.
- Crash affecting core beta flows.

## Rollback Steps

1. Stop beta rollout or pause tester invites.
2. Disable live notification provider mode if push is implicated.
3. Revert backend deployment to last known good release.
4. Pull mobile build from TestFlight/Play internal track if app-side regression.
5. Notify testers with workaround/status.

## WAF / Rate Limiting Checklist

- [ ] API rate limit configured for auth endpoints.
- [ ] API rate limit configured for public environment/planner endpoints.
- [ ] Admin/ops endpoints restricted and token-protected.
- [ ] Abuse logging monitored.

Status: BLOCKED_EXTERNAL until deployment evidence exists.

## Logs To Monitor

- `/api/health` availability.
- Auth signup/login errors.
- Risk/dashboard/planner latency and 5xx.
- Notification provider-health and credentials-health.
- Notification delivery attempts/failures.
- Privacy export/delete failures.
- Subscription webhook failures.

## Tester Feedback Intake

- Feedback channel: BLOCKED_EXTERNAL.
- Bug report template: `docs/bug-report-template.md`.
- Daily triage owner: BLOCKED_EXTERNAL.

## Daily Beta Review Checklist

- [ ] Backend health and error rate reviewed.
- [ ] Mobile crash/feedback reviewed.
- [ ] Push delivery attempts reviewed.
- [ ] Privacy/delete/export failures reviewed.
- [ ] New blockers assigned owner and priority.

## Go/No-Go Meeting Checklist

- [ ] Backend smoke/preflight evidence attached.
- [ ] iOS real-device QA evidence attached.
- [ ] Android real-device QA evidence attached.
- [ ] Push E2E status accepted.
- [ ] Store/legal external blockers accepted or closed.
- [ ] On-call owner confirmed.
