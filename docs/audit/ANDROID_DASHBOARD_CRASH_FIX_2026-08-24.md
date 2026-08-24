# Android Dashboard Crash Fix — Status 2026-08-24

**Verdict:** Root cause **fixed in code**; reproducible monitor gate **PASS** (2026-08-24-gate-v5)

## Root cause (confirmed)

`AtmosphericParticlesView` started `ValueAnimator` in `init`. When `refreshEntitlement` invoked `renderCurrentScreen` from a background thread, Dashboard attach triggered:

`android.util.AndroidRuntimeException: Animators may only be run on Looper threads`

## Fix (`d0d14954` and follow-up)

- Animator starts in `onAttachedToWindow()` (main thread) only
- Animator stops in `onDetachedFromWindow()`
- Production entitlement callback wrapped with `runOnUiThread` in `AppMainActivity`
- DEBUG store-shot mode skips `refreshEntitlement` network call

## What is NOT sufficient proof

- Ad-hoc `PID=2867` after manual launch
- Single screenshot without semantic gates
- Emulator reuse without explicit serial

## Required gate (pending PASS)

Run `scripts/ops/android_dashboard_monitor.sh` on deterministic phone AVD serial:

1. APK from current source SHA + SHA-256 recorded
2. Install + DEBUG state reset
3. Store-shot Dashboard launch
4. PID + foreground `com.hiair` + marker `screen.dashboard.root`
5. No `FATAL EXCEPTION` in logcat
6. Process alive ≥ 60s
7. force-stop → relaunch, background → foreground, recreate, 3 sequential launches

Evidence root: `.evidence/android-dashboard-monitor/<timestamp>/`

## Matrix status

| Item | Status |
|------|--------|
| Dashboard crash root cause | FIXED (code) |
| Dashboard reproducible monitor gate | **PASS** | `.evidence/android-dashboard-monitor/2026-08-24-gate-v5/` |
| Android 8-screen phone capture | **FAIL / EVIDENCE INVALID** (prior runs) |
| Android 8-screen tablet capture | **FAIL / EVIDENCE INVALID** (prior runs) |
| Android matrix overall | **FAIL** until new validated runs |

Prior invalid captures: `docs/audit/INVALID_ANDROID_CAPTURE_RUNS_2026-08-24.md`
