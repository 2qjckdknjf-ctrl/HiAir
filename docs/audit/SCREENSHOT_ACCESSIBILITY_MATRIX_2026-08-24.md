# Screenshot & Accessibility Matrix — 2026-08-24

**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Base commit:** `09b7823e` (post-hardening; evidence under `.evidence/` is generated output)  
**Legend:** PASS = verified locally; FAIL = defect; PENDING = runnable but not executed; BLOCKED = attempted and impossible (missing dependency)

## iOS — Simulator matrix

| Cell | Status | Evidence | Notes |
|------|--------|----------|-------|
| iPhone 16e / EN / standard | PASS | `.evidence/ios-screenshots/2026-08-24-matrix-iphone16e-en-v2/` | UDID `61119C43…`, iOS 26.2, 10/10 PNG + manifest |
| iPhone 17 Pro / EN / standard | PASS | `.evidence/ios-screenshots/2026-08-24-matrix-iphone17pro-en-v2/` | UDID resolved via `resolve_ios_simulator.sh` |
| iPhone 17 Pro / RU / standard | PASS | `.evidence/ios-screenshots/2026-08-24-matrix-iphone17pro-ru-v4/` | `AppleLanguages=(ru)` + host observed-env gate |
| iPad Pro 13" (M5) / EN / standard | PASS | `.evidence/ios-screenshots/2026-08-24-matrix-ipad-pro13-en/` | `userInterfaceIdiom=pad`, regular width |
| iPad Pro 13" (M5) / RU / standard | PASS | `.evidence/ios-screenshots/2026-08-24-matrix-ipad-pro13-ru/` | |
| accessibility3 / iPhone 17 Pro | PASS | `.evidence/ios-screenshots/2026-08-24-matrix-iphone17pro-a11y3-v2/` | `-UIPreferredContentSizeCategoryName=AccessibilityM` |
| accessibility5 / iPhone 17 Pro | PASS | `.evidence/ios-screenshots/2026-08-24-matrix-iphone17pro-a11y5-v2/` | AccessibilityXXXL |
| Reduce Motion | PASS | `.evidence/ios-screenshots/2026-08-24-matrix-iphone17pro-reduce-motion-v2/` | Launch arg + observed gate |
| Reduce Transparency | PASS | `.evidence/ios-screenshots/2026-08-24-matrix-iphone17pro-reduce-transparency-v2/` | Launch arg + observed gate |
| loading / empty / error / offline | PASS | `HiAirUITests/MatrixStateScreenshotTests` (5/5 green) | PNGs under `/tmp` matrix dirs during test run |
| account deletion recovery | PASS | `MatrixStateScreenshotTests/testCaptureAccountDeletionRecovery` | Settings partial-deletion detail seeded |
| onboarding / paywall / Settings | PASS | Store suite cells in each capture dir | Included in 10-PNG contract |
| Paywall scroll / tab clearance | PASS | `PaywallScrollSafeAreaUITests`, `MainTabScrollHittabilityUITests` | Post fade/paywall fix |
| TalkBack manual pass | PENDING | — | Automatic hierarchy only; manual TalkBack walk not run |

## Android

| Cell | Status | Evidence | Notes |
|------|--------|----------|-------|
| EN / phone / 8 screens | PASS | `.evidence/android-screenshots/2026-08-24-phone-en/` | DEBUG mock seed; `android-34` AVD `hiair-qa-phone` |
| EN / tablet / 8 screens | PASS | `.evidence/android-screenshots/2026-08-24-tablet-en/` | AVD `hiair-qa-tablet` |
| Deep Glass parity (8 screens) | PARTIAL | screenshots above | Glass cards on dashboard; nav blur; full renderer sweep incomplete |
| RU locale captures | PENDING | — | Pipeline supports `HIAIR_SHOT_LANGUAGE=ru`; not re-shot this pass |
| Espresso bootstrap smoke | PASS | `StoreScreenshotInstrumentedTest` | Launches dashboard under store-shot intent |
| TalkBack manual | PENDING | — | uiautomator hierarchy not automated this pass |

## Release verification

| Gate | Status | Evidence |
|------|--------|----------|
| iOS Release build | PASS | `scripts/ops/verify_ios_release_leaks.sh` → `.evidence/ios-release-verify/20260824-151937/` |
| iOS unit + UI | PASS | 213 unit + 27 UI (incl. matrix state) |
| Backend pytest | PASS | ~76% cov, 70% gate |
| Android lint/unit/debug/release/bundle | PASS | `assembleDebug`, `bundleRelease`, `lint`, `test` |
