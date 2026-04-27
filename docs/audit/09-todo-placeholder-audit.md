# TODO / Placeholder Audit

## Summary

Placeholder scan found a mix of safe development placeholders, intentional stub/mock modes, and real beta/store blockers. Safe technical blockers found during this pass were fixed; external/legal placeholders remain.

## Safe placeholders

| Item | Status | Notes |
|---|---|---|
| Mock environmental source | DONE | Intentional local/dev path |
| Stub notification provider | PARTIAL | Acceptable for non-live beta only |
| Stub subscription provider | PARTIAL | Acceptable for technical beta scaffold |
| CI test secrets | DONE | Non-production test values |

## Real blockers

| Item | Status | Required action |
|---|---|---|
| Store packet `[TBD]` support/privacy URLs | BLOCKED_EXTERNAL | Provide final URLs |
| Store screenshots unchecked | NEEDS_MANUAL_QA | Capture final store screenshots |
| Legal contact/controller placeholders | LEGAL_SIGNOFF_REQUIRED | Legal owner must finalize |
| APNs/FCM mobile token flow incomplete | MISSING | Wire mobile push registration |
| DB smoke unavailable locally | BLOCKED_BY_ENV | Start/provision Postgres |

## Fixed now

- iOS project source membership for `HiAirV2Theme.swift`.
- Backend protected-env ops token fail-closed behavior.
- Android backup setting for session/token risk.
- Backend README migration/auth docs.

## Remaining

No mass placeholder rewrite was performed because several placeholders represent intentionally unfilled external/legal values.
