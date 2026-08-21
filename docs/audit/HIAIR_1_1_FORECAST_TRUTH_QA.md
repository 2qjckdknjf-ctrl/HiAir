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

## Local re-check (2026-08-21)

Additional pass after code-complete:

- Fixed exclusive safe-window ends (`08:00` hour → end `09:00`, no more `08:00–08:00`)
- `recommendations` + dashboard overview now pass personal load + hourly like current-risk
- Skip DB snapshot insert when required NOT NULL metrics are missing
- Cached snapshot load is null-safe for aqi/pm25/ozone
- iOS/Android DTOs accept null humidity/aqi/pm25/ozone
- Live Open-Meteo smoke: Barcelona/Cairo/Phoenix TZ offsets OK

### Deeper honesty pass (same day)

- Clip hourly to current+future only (live: 0 past hours; first slot = current hour)
- Air-unknown → `moderate` + `air_data_unavailable` (never fake `low`)
- Personal load skips AQI rules when AQI is null (no `aqi or 0`)
- `safeWindows` = outdoor types only; ventilation only in `ventilationWindows`
- Briefing / AI reports / dashboard use `forecast.current` from the same forecast bundle
- Cached/stale point provenance labeled `cached`
- Legacy `/api/planner/daily` uses engine outdoor gate
- Android planner auto-load + premium locked card; iOS 402 handles `serverWithDetail`

### Closure pass (same day)

- `current-risk.safeWindows` outdoor-only; `ventilationWindows` additive on risk payload
- Planner UI appends concrete `missingMetrics` when `dataQuality=partial`
- Dashboard (iOS/Android) still shows ventilation with typed labels from `ventilationWindows`
- Planner shows provider `sources` (iOS + Android, localized)
- Pre-1.1 audit doc marked as frozen baseline (not current branch behavior)

Still blocked on production deploy + device QA for READY verdict.

## DoD checklist (spec §27)

Code-level (this branch):

- [x] real hourly weather forecast used in planner
- [x] real hourly air when available; missing explicit
- [x] production synthetic future projection removed
- [x] UV / PM10 / wind direct-provider or unavailable
- [x] forecast provenance + freshness
- [x] timezone location-correct + DST tests
- [x] safe windows from actual forecast points
- [x] Dashboard / Premium / HealthKit contracts preserved in code
- [x] iOS/Android unit tests + backend forecast suite
- [x] no fake/sample production forecast path
- [x] source-of-truth docs updated

External (still open):

- [ ] production smoke on `api.hiair.io`
- [ ] new TestFlight physical QA

