# HiAir Development Handoff for Next Agent

Date: 2026-07-21 (Physical device certification in progress)

## Current verdict

**DEVICE CERTIFICATION IN PROGRESS**

Do **not** claim `READY FOR FIRST USERS` until interactive iPhone matrix in `docs/release/qa/REAL_DEVICE_QA_REPORT.md` is PASS (geo + HealthKit + StoreKit purchase + privacy + a11y).

## Proven this session

| Item | Evidence |
|------|----------|
| `main` @ `fa0d91b` pushed | product polish + build 92 |
| Production SHA | `fa0d91b` on `https://api.hiair.io/api/health` |
| Health API | unauth summary/insights **401** |
| Schema 018/019 | present on hiair-prod (`wearable_metric_daily`, etc.) |
| Preflight | backend pytest, iOS tests, Android assemble/lint/test, `hiair_final_gate.sh` **PASS** |
| Physical iPhone | **HiAir 0.1.0 (92)** installed via `devicectl`; launch works when unlocked |
| TestFlight 92 | VALID `cbd0b02f-3f78-42e8-a939-945210419d8a`; groups «Первый»/«Первые» |
| Android USB | none attached |

## Blockers (honest)

1. **Interactive E2E not completed** — Maestro physical driver failed/flaky (2.3→2.7.0; `--apple-team-id 43A4KW5BKB`). Need human TF 92 session or working XCUITest/Maestro driver.
2. **StoreKit purchase** — not run on TF 92; historical build 81 catalog FAIL must be retested.
3. **Android device + Play Billing** — EXTERNALLY BLOCKED without device / Play Console app.
4. **x86 `gh`** on this Mac — use HTTPS git + ASC API Python; GitHub Actions dispatch may need PAT.

## Immediate next actions

1. On unlocked iPhone: TestFlight → install **92** → delete old if needed → run full checklist in QA report.
2. For automation: upgrade/fix Maestro iOS real-device driver, or add HiAirUITests destination physical device.
3. After each interactive FAIL: minimal code fix → bump build → TF upload → retest that scenario only, then full regression.
4. Android: attach USB device for Health Connect path even if Billing stays blocked.

## Quick commands

```bash
curl -sS https://api.hiair.io/api/health
bash scripts/release/hiair_final_gate.sh
cd mobile/ios && bash scripts/archive_and_upload_testflight.sh
cd mobile/ios && bash scripts/upload_ipa_testflight_api.sh
xcrun devicectl device info apps --device 8A9FB747-7B0F-5C0E-A51F-EC23592F51F4 | grep -i hiair
```

## Docs

- `docs/release/qa/REAL_DEVICE_QA_REPORT.md` — live certification matrix
- `docs/release/FINAL_RELEASE_PROGRAM_STATUS.md`
- `docs/health/HEALTH_INTELLIGENCE_RELEASE_STATUS.md`
