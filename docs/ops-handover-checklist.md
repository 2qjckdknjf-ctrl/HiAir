# HiAir Ops Handover Checklist

Use this checklist before enabling scheduled backend maintenance jobs in staging/production.

## 1) Access and ownership

- [ ] Confirm service owner for backend operations.
- [ ] Confirm on-call contact for failed scheduled jobs.
- [ ] Verify least-privilege DB credentials for maintenance job runner.

## 2) Environment readiness

- [ ] `JWT_SECRET` is strong and non-default.
- [ ] `NOTIFICATION_ADMIN_TOKEN` is set and stored in secret manager.
- [ ] Retention env values are explicitly configured:
  - [ ] `RETENTION_NOTIFICATION_DELIVERY_ATTEMPTS_DAYS`
  - [ ] `RETENTION_NOTIFICATION_EVENTS_DAYS`
  - [ ] `RETENTION_SUBSCRIPTION_WEBHOOK_EVENTS_DAYS`
  - [ ] `RETENTION_SECRET_ROTATION_EVENTS_DAYS`
- [ ] `scripts/check_env_security.py --strict` passes in target environment.

## 3) Backup and rollback safety

- [ ] DB backup policy is active and tested (point-in-time or daily snapshots).
- [ ] Restore procedure is documented and tested on recent backup.
- [ ] Rollback owner and response SLA are documented.

## 4) Scheduler setup

- [ ] Choose scheduler mode:
  - [ ] cron
  - [ ] systemd timer
- [ ] Configure execution command:
  - [ ] `scripts/retention_cleanup.py --dry-run` for initial rollout window
  - [ ] `scripts/retention_cleanup.py` for normal operation
- [ ] Configure log destination and retention for job logs.

## 5) Monitoring and alerting

- [ ] Alert on non-zero exit code for retention job.
- [ ] Alert on unusual deletion spikes by table.
- [ ] Dashboard/traces include last successful run timestamp.
- [ ] Incident commander and communication channel are predefined.
- [ ] `docs/incident-response-runbook.md` reviewed by on-call owner.

## 6) Validation after go-live

- [ ] Run first dry-run and review counts with product/security owner.
- [ ] Run first real cleanup in supervised window.
- [ ] Confirm no regressions in key API flows after cleanup.
- [ ] Record completion in release/change log.
- [ ] Generate retention evidence JSON from dry-run and attach to release packet.
