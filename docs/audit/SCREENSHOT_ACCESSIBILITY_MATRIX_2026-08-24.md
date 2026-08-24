# Screenshot & Accessibility Matrix — 2026-08-24

**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Legend:** PASS = verified locally; FAIL = defect or invalid evidence; PENDING = not executed; BLOCKED = external dependency

## iOS — Simulator matrix

| Cell | Status | Evidence | Notes |
|------|--------|----------|-------|
| iPhone 16e / EN / standard | PENDING | — | Prior matrix under `.evidence/ios-screenshots/2026-08-24-matrix-*` **not final** until `app-observed-environment.json` pipeline re-run |
| iPhone 17 Pro / EN / standard | PENDING | — | Same — old runs used synthesized observed env |
| iPhone 17 Pro / RU / standard | PENDING | — | Re-capture required |
| iPad Pro 13" / EN / standard | PENDING | — | Re-capture required |
| iPad Pro 13" / RU / standard | PENDING | — | Re-capture required |
| accessibility3 / iPhone 17 Pro | PENDING | — | Must prove distinct observed `contentSizeCategory` vs standard |
| accessibility5 / iPhone 17 Pro | PENDING | — | Must prove distinct observed category + geometry contract |
| Reduce Motion | PENDING | — | App runtime `reduceMotionEnabled` required |
| Reduce Transparency | PENDING | — | App runtime flag required |
| loading / empty / error / offline | PASS | `HiAirUITests/MatrixStateScreenshotTests` (prior run) | Re-run after env pipeline green |
| Paywall scroll / tab clearance | PASS | `PaywallScrollSafeAreaUITests`, `MainTabScrollHittabilityUITests` | |
| VoiceOver manual pass | PENDING | — | Manual VoiceOver walk not run; automatic hierarchy only |

### iOS observed environment

| Check | Status | Notes |
|-------|--------|-------|
| App writes `app-observed-environment.json` | FIXED (code) | `ScreenshotEnvironmentReporter` — runtime Locale/traits/accessibility |
| Test writes `requested-environment.json` only | FIXED (code) | `StoreScreenshotTests` — no synthetic observed |
| Shell synthesis fallback removed | FIXED (code) | `capture_ios_screenshots.sh` fails if app file missing |
| Matrix re-captured with new proof | PENDING | Required before PASS |

## Android

| Cell | Status | Evidence | Notes |
|------|--------|----------|-------|
| EN / phone / 8 screens | **FAIL / EVIDENCE INVALID** | `.evidence/android-screenshots/2026-08-24-phone-en/` | Crash/launcher/error frames — see `docs/audit/INVALID_ANDROID_CAPTURE_RUNS_2026-08-24.md` |
| EN / tablet / 8 screens | **FAIL / EVIDENCE INVALID** | `.evidence/android-screenshots/2026-08-24-tablet-en/` | Wrong screen/crash/launcher — preserved as failure evidence |
| Deep Glass parity (8 screens) | PARTIAL | invalid captures only | Renderer sweep in progress |
| RU locale captures | PENDING | — | Pipeline supports `HIAIR_SHOT_LANGUAGE=ru`; no valid captures yet |
| Espresso / instrumentation 8-screen | PENDING | `StoreScreenshotInstrumentedTest` rewritten | Must pass on isolated emulator |
| TalkBack manual | PENDING | — | Automatic hierarchy checks in new capture script; manual TalkBack not run |

## Release verification

| Gate | Status | Evidence |
|------|--------|----------|
| iOS Release build | PASS (prior) | Re-verify after iOS matrix re-run |
| Backend pytest | PENDING | Re-run after commits |
| Android lint/unit/debug/release/bundle | PENDING | Re-run after Android fixes |
| Provenance contract test | PENDING | `scripts/ops/test_provenance_manifest_contract.sh` |

## Invalid evidence registry

See [`docs/audit/INVALID_ANDROID_CAPTURE_RUNS_2026-08-24.md`](INVALID_ANDROID_CAPTURE_RUNS_2026-08-24.md).
