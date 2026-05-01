# Feature Spec: Morning Briefing

Status: spec frozen for cycle "aurora-calm + insights"
Owner: backend + mobile
Last updated: 2026-05-01

## Goal

One scheduled, personalized push notification per day, delivered at the user's
chosen local time, with a calm wellness summary of today's risk and the best
window for outdoor activity.

The goal is to convert a reactive product (push when risk changes) into a
ritual product (one expected daily moment). Open rates and retention rise.

## Non-goals

- Multiple briefings per day. One only.
- Real-time recompute. Briefing is a snapshot at dispatch time.
- SMS or email channel. Push only.
- Replacing reactive risk-change alerts. Both coexist; quiet hours and dedup
  apply to both.

## User-facing surface

Settings → Notifications → Morning Briefing section with:
- Toggle "Morning Briefing" (off by default at first onboarding)
- Time picker (default 07:30, 24-hour format, in the profile's timezone)
- Helper text: "A calm summary delivered every morning."

Push payload appears as standard system notification. Tap opens the Dashboard.

## Briefing composition

For a user at dispatch time, the briefing service:
1. Loads the user's primary profile (most recently updated).
2. Computes today's risk via the deterministic core.
3. Computes today's day plan and picks the earliest safe outdoor window.
4. Produces a recommendation card.
5. Asks the AI explanation layer for two short sentences in the user's preferred
   language. Falls back to a template if LLM unavailable.

Push body shape:
```
{greeting}. {risk_summary} {best_window}. {action_hint}
```

Example (en):
> Good morning, Alex. Today's risk is moderate due to ozone. Best outdoor window
> 18:30–20:00. Ventilate after 22:00.

Example (ru):
> Доброе утро, Alex. Сегодня риск умеренный из-за озона. Лучшее окно для улицы
> 18:30–20:00. Проветривание после 22:00.

Title: localized "Morning Briefing" / "Утренний бриф".

## Data model

Migration `007_briefing_schedule.sql`:

```sql
CREATE TABLE IF NOT EXISTS briefing_schedule (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    local_time TIME NOT NULL DEFAULT '07:30',
    timezone TEXT NOT NULL DEFAULT 'UTC',
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    last_sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_briefing_schedule_enabled
    ON briefing_schedule(enabled, last_sent_at);
```

`timezone` is the IANA name. Source of truth is `profiles.timezone` of the
user's primary profile, copied here at schedule creation/update for fast lookup.
Resync on profile update via repository helper.

## Due logic

A briefing is "due" if:
- enabled = true
- now in user's timezone has the same hour and minute (truncated to minute) as
  `local_time`
- `last_sent_at` is null OR older than 18 hours UTC

The 18-hour guard prevents double-sends across DST shifts and clock skew.

## Dispatch worker

Script `backend/scripts/dispatch_briefings.py`:
- Loads all enabled rows
- For each row, evaluates due logic
- If due, composes briefing and dispatches via existing notification provider
- Updates `last_sent_at = now_utc()`
- Logs per-user outcome

Cron: every 5 minutes. Window 5 minutes is small enough that user perceives
the briefing at the chosen minute ±2.5 min, large enough to absorb job lag.

## API contract

### GET /api/briefings/schedule

Returns current schedule for the authenticated user. If no row exists, returns
defaults (enabled=false, local_time=07:30, timezone from primary profile).

```json
{
  "enabled": false,
  "local_time": "07:30",
  "timezone": "Europe/Madrid",
  "last_sent_at": null
}
```

### PUT /api/briefings/schedule

Body:
```json
{
  "enabled": true,
  "local_time": "07:00"
}
```

`timezone` is not user-settable. Always synced from primary profile.

Response 200: returns the updated row (same shape as GET).

### Errors

| Status | Reason                                      |
|--------|---------------------------------------------|
| 401    | Missing or invalid auth                     |
| 422    | Invalid local_time format                   |
| 422    | User has no primary profile yet             |
| 503    | Database unavailable                        |

## Privacy

`briefing_schedule` is user-linked.
- Included in `GET /api/privacy/export` (key `briefing_schedule`).
- Cleaned by CASCADE on user delete.
- Documented in `docs/data-retention-matrix.md`.

`notification_delivery_attempts` already covers briefing dispatch logs, no new
table needed.

## Localization keys (added in this cycle)

```
briefing.title
briefing.greeting
briefing.fallback.body
briefing.tap_hint
briefing.section_header
briefing.toggle_label
briefing.time_label
briefing.helper_text
```

Added to ru + en simultaneously.

## Interaction with quiet hours and dedup

Morning Briefing is a scheduled notification, not an alert. It still respects
the user's `quiet_hours_start`/`quiet_hours_end` settings: if the chosen
`local_time` falls inside quiet hours, the briefing is suppressed and
`last_sent_at` is still updated to avoid late-window catch-up.

It does not participate in alert dedup keys (those are for risk-change events).

## Tests

- `backend/tests/test_briefing_due_logic.py`
  - Same minute, fresh user → due
  - Same minute, sent 2 hours ago → not due (18h guard)
  - Same minute, sent 20 hours ago → due
  - DST forward shift case
  - DST backward shift case
- `backend/tests/test_briefing_compose.py`
  - Output contains greeting, risk word, time window
  - Russian preferred_language → russian text
  - Fallback path when OPENAI_API_KEY missing
- `backend/tests/test_briefing_api.py`
  - Auth required
  - PUT updates row, GET reflects update
  - Invalid local_time rejected
  - User without primary profile → 422
- `backend/tests/test_briefing_no_double_send.py`
  - Two dispatch runs in 10 minutes send only one push

## Verification at cycle exit

- All four test modules pass
- `scripts/dispatch_briefings.py --dry-run` lists due users correctly
- `scripts/smoke_db_flow.py` extended with briefing schedule check
- Manual QA: enable briefing on test device, set time +2 min, receive push
- Privacy export contains the briefing_schedule row

## Out of scope for this cycle

- Multiple briefings per day
- Custom briefing templates
- Briefing preview screen in-app
- Quiet-hours auto-shift suggestion
