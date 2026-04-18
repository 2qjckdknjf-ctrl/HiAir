# HiAir Retention Operations Runbook

This runbook defines how to execute and schedule operational data retention cleanup.

## Scope

Current cleanup script: `backend/scripts/retention_cleanup.py`

Covered tables:
- `notification_delivery_attempts`
- `notification_events` (only records with `profile_id IS NULL`)
- `subscription_webhook_events`
- `notification_secret_rotation_events`

Reference retention matrix: `docs/data-retention-matrix.md`

## Retention configuration

Set in environment:

- `RETENTION_NOTIFICATION_DELIVERY_ATTEMPTS_DAYS` (default `90`)
- `RETENTION_NOTIFICATION_EVENTS_DAYS` (default `180`)
- `RETENTION_SUBSCRIPTION_WEBHOOK_EVENTS_DAYS` (default `180`)
- `RETENTION_SECRET_ROTATION_EVENTS_DAYS` (default `365`)

## Manual execution

From `backend/`:

```bash
.venv/bin/python scripts/retention_cleanup.py --dry-run
.venv/bin/python scripts/retention_cleanup.py
.venv/bin/python scripts/retention_cleanup.py --dry-run --json-output ../docs/_operator/evidence/retention-dry-run.json
```

Recommended process:
1. Run dry-run and capture output.
   - Prefer JSON report mode for audit portability.
2. Confirm deletion volume is expected.
3. Run non-dry cleanup.
4. Store logs in ops channel/ticket.

## Scheduling options

### Option A: cron (daily at 03:20)

Example crontab entry:

```bash
20 3 * * * cd /path/to/HIAir/backend && /path/to/HIAir/backend/.venv/bin/python scripts/retention_cleanup.py >> /var/log/hiair-retention.log 2>&1
```

### Option B: systemd timer (Linux)

`/etc/systemd/system/hiair-retention.service`:

```ini
[Unit]
Description=HiAir retention cleanup job
After=network.target

[Service]
Type=oneshot
WorkingDirectory=/path/to/HIAir/backend
ExecStart=/path/to/HIAir/backend/.venv/bin/python scripts/retention_cleanup.py
User=hiair
Group=hiair
```

`/etc/systemd/system/hiair-retention.timer`:

```ini
[Unit]
Description=Run HiAir retention cleanup daily

[Timer]
OnCalendar=*-*-* 03:20:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now hiair-retention.timer
sudo systemctl status hiair-retention.timer
```

## Safety and rollback

- Cleanup targets only operational/audit-like records; it does not delete users/profiles/symptom/risk core data.
- Start with conservative retention windows.
- If accidental over-cleanup is detected, restore from latest DB backup and increase retention window before rerun.

## Monitoring checklist

- Last successful run timestamp.
- Deleted row counts by table.
- Unexpected spikes in deletion volume.
- Error logs (DB connectivity, SQL failures, permission issues).
