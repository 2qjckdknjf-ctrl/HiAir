# Store-Ready Hardening Status — 2026-08-24

**Verdict:** `NO-GO / HARDENING IN PROGRESS`  
**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Worktree:** `/Users/alex/Projects/HIAir-store-ready`

## Corrected this pass

- **Android evidence invalidated:** phone/tablet 2026-08-24 captures marked `FAIL / EVIDENCE INVALID` (crash dialog, launcher, load errors). Failure evidence preserved; see `docs/audit/INVALID_ANDROID_CAPTURE_RUNS_2026-08-24.md`.
- **Dashboard crash root cause:** fixed in `d0d14954` (animator lifecycle + main-thread render); reproducible monitor gate **PENDING** — see `docs/audit/ANDROID_DASHBOARD_CRASH_FIX_2026-08-24.md`.
- **Provenance model:** remove self-referential `manifest_file_sha256` from JSON; file SHA only in `.sha256` sidecar; `manifest_payload_sha256` with canonicalization; contract test script.
- **iOS observed environment:** app writes `app-observed-environment.json` from runtime; test writes `requested-environment.json`; shell synthesis removed.
- **Android capture pipeline:** emulator serial isolation, semantic validation, foreground package checks, hierarchy XML + logcat, app observed env pull.
- **Android screenshot state:** DEBUG seeder for offline Planner/Insights/Symptoms; mock billing on paywall; screen root markers; instrumentation covers 8 screens (no `pressHome` success).

## Still open (local)

- Re-run full iOS matrix with runtime observed proof
- Valid Android phone/tablet EN + RU + a11y captures with manual visual review (16 PNG)
- Android Deep Glass V4 full renderer parity (8 screens)
- Full backend/iOS/Android gate table with current HEAD SHA
- RC provenance manifest (separate commit) **only after all local gates green**

## External blockers (unchanged)

- Physical-device ASC Sandbox IAP
- Production signing + ASC/Play upload/submit
- Production deploy/secrets rotation

## Owner actions

1. Review invalid Android failure evidence paths (do not treat as PASS)
2. After agent reports green local gates — review new `.evidence/android-screenshots/*` and iOS matrix dirs
3. Physical Sandbox IAP when ready
4. Explicit «можно сабмитить» before ASC/Play submit
