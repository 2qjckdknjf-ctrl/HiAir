# Screenshot & Accessibility Matrix — 2026-08-24 (updated)

**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**HEAD:** post-`d0d14954` hardening commits  
**Legend:** PASS = verified; SEMANTIC PASS = automated gates only; VISUAL PENDING = PNG not manually reviewed; FAIL = invalid/defect

## Android

| Cell | Status | Evidence | Notes |
|------|--------|----------|-------|
| EN / phone / 8 screens (prior) | **FAIL / EVIDENCE INVALID** | `.evidence/android-screenshots/2026-08-24-phone-en/` | See `INVALID_ANDROID_CAPTURE_RUNS_2026-08-24.md` |
| EN / tablet / 8 screens (prior) | **FAIL / EVIDENCE INVALID** | `.evidence/android-screenshots/2026-08-24-tablet-en/` | Same |
| EN / phone / 8 screens (new) | **SEMANTIC PASS / VISUAL PENDING** | `.evidence/android-screenshots/2026-08-24-phone-en-v6/` | serial `emulator-5554`, AVD `hiair-qa-phone`, manifest `status=PASS` |
| EN / tablet / 8 screens (new) | **SEMANTIC PASS / VISUAL PENDING** | `.evidence/android-screenshots/2026-08-24-tablet-en-v2/` | serial `emulator-5554`, AVD `hiair-qa-tablet` |
| Dashboard monitor gate | **PASS** | `.evidence/android-dashboard-monitor/2026-08-24-gate-v5/` | 60s + relaunch/recreate cycles |
| Deep Glass parity | **PARTIAL** | new captures | Semantic OK; visual parity not signed off |
| RU phone/tablet | **PENDING** | — | Pipeline ready |
| a11y font scale / reduce motion | **PENDING** | — | |
| TalkBack manual | **PENDING** | — | |

## iOS

Unchanged — matrix re-capture **PENDING** until `app-observed-environment.json` pipeline re-run.

## Tooling

| Gate | Status |
|------|--------|
| `test_android_capture_validate.py` | PASS |
| Provenance contract test | PASS (prior commit) |

**Overall verdict:** `NO-GO / HARDENING IN PROGRESS` — Android semantic captures green; visual review + RU/a11y + iOS matrix remain.
