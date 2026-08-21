# HiAir 1.1 Forecast Truth — QA notes

**Verdict: CODE COMPLETE — WAITING FOR PRODUCTION/DEVICE QA**

Do not claim `HIAIR 1.1 FORECAST TRUTH READY` until both gates below pass.

## Not done on this branch

| Gate | Status |
|------|--------|
| Backend deploy to `https://api.hiair.io` | NOT RUN |
| Authenticated production smoke (`scripts/release/smoke_forecast_truth.py`) | NOT RUN |
| TestFlight build with 1.1 code | NOT RUN |
| Physical-device QA (spec §25) | NOT RUN |

## Local code gates (this worktree)

- Static production scan: `scripts/release/check_forecast_integrity.py`
- Backend pytest in `backend/`
- iOS Debug simulator build + `HiAirTests`
- Android `testDebugUnitTest`

## After backend deploy

```bash
HIAIR_ACCESS_TOKEN=... HIAIR_PROFILE_ID=... \
  python scripts/release/smoke_forecast_truth.py --require-hourly
```

Confirm:

- `current-risk` source is live/cached, never `sample`/`mock`
- `day-plan` hourly points are ordered and timezone matches the location
- missing metrics are null/unavailable, not fabricated
- Premium 402 on planner is unchanged for non-premium accounts

## Physical device matrix (spec §25)

Run on a new TestFlight build after production smoke passes. Do not certify from simulator alone.
