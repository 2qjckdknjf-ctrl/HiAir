# HiAir Data Retention Matrix

Last updated: 2026-04-18

This matrix maps current backend tables to retention handling status.

## Legend

- **core-user-data**: user account/product history that should be removed via account deletion, not time-based retention cleanup.
- **ops-log**: operational/audit-like data suitable for time-based cleanup.
- **unmanaged**: no automated time-based cleanup yet; requires explicit policy decision.

## Matrix

| Table | Category | Current automated handling | Control |
|---|---|---|---|
| `users` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |
| `profiles` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |
| `user_settings` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |
| `symptom_logs` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |
| `risk_scores` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |
| `risk_assessments` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |
| `ai_recommendations` | core-user-data | deleted indirectly through risk-assessment/profile cascade | `POST /api/privacy/delete-account` |
| `ai_explanation_events` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |
| `alert_events` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |
| `notification_events` | mixed | profile-linked rows removed by account deletion; orphan/system rows cleaned by retention script | `delete-account` + `retention_cleanup.py` |
| `push_device_tokens` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |
| `notification_delivery_attempts` | ops-log | time-based cleanup implemented | `RETENTION_NOTIFICATION_DELIVERY_ATTEMPTS_DAYS` |
| `subscription_webhook_events` | ops-log | time-based cleanup implemented | `RETENTION_SUBSCRIPTION_WEBHOOK_EVENTS_DAYS` |
| `notification_secret_rotation_events` | ops-log | time-based cleanup implemented | `RETENTION_SECRET_ROTATION_EVENTS_DAYS` |
| `user_subscriptions` | core-user-data | deleted on account deletion flow | `POST /api/privacy/delete-account` |

## Verification procedure

1. **Privacy deletion proof**
   - Run `backend/scripts/smoke_db_flow.py`.
   - Confirm residual-data assertions pass.
2. **Retention dry-run proof**
   - Run `backend/scripts/retention_cleanup.py --dry-run --json-output <path>`.
   - Attach JSON report to release evidence packet.
3. **Retention apply proof**
   - Run `backend/scripts/retention_cleanup.py` in supervised window.
   - Record deleted counts by table in change log.

## Current gaps

- Final production retention windows require product/legal signoff.
- Scheduling ownership and monitoring alerts require ops owner confirmation.
