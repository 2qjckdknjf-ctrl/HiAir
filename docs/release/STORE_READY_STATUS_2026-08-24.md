# Store-Ready Hardening Status — 2026-08-24 (final local closure)

**Verdict:** `CODE-READY / EXTERNAL ACTIONS REQUIRED`  
**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Worktree:** `/Users/alex/Projects/HIAir-store-ready`  
**Local commits:** `b9e04bd0` → `a2d6da7d` (6 atomic commits on top of `002dc60d`)

## Android local closure (2026-08-25)

| Gate | Status | Evidence |
|------|--------|----------|
| JVM (assembleDebug, bundleRelease, unit, lint) | **PASS** | device-gates JVM stage |
| Capture shelf regression | **PASS** (6/6) | `scripts/ops/test_android_capture_shelf.py` |
| Device gates | **PASS** (21/21) | `.evidence/android-device-gates/20260825-post-commit-v2/` |
| Geometry matrix | **PASS** (8/8) | `.evidence/android-geometry-matrix/20260825-post-commit-v4/` |
| Targeted visual 12-shot | **SEMANTIC 12/12 + VISUAL 12/12** | `.evidence/android-targeted-visual/dev-20260825-v4-visual-4c/` |
| Full Phone EN 8-screen | **SEMANTIC 8/8 + VISUAL 8/8** | `.evidence/android-screenshots/20260825-phone-en-v4c-v3/` |
| Full Tablet EN 8-screen | **SEMANTIC 8/8 + VISUAL 8/8** | `.evidence/android-screenshots/20260825-tablet-en-v4c/` |
| RC provenance manifest | **GENERATED** (clean tracked tree) | `docs/release/RC_PROVENANCE_MANIFEST_2026-08-25.json` (`rc_source_sha=7d90e5df`) |

## Corrected this pass

- **Android evidence invalidated:** phone/tablet 2026-08-24 captures marked `FAIL / EVIDENCE INVALID` (crash dialog, launcher, load errors). Failure evidence preserved; see `docs/audit/INVALID_ANDROID_CAPTURE_RUNS_2026-08-24.md`.
- **Dashboard crash root cause:** fixed in `d0d14954` (animator lifecycle + main-thread render).
- **Capture pipeline:** shelf-aware crop, `store.*.ready` fail-closed readiness, visual-review ↔ manifest sync.
- **Deep Glass V4 responsive hardening:** 12/12 visual PASS on `dev-20260825-v4-visual-4c`.
- **Six atomic commits** landed on feature branch (capture → tests → presentation → nav clearance → instrumentation → docs).

## Still external (not local blockers)

- Physical-device ASC Sandbox IAP + Play internal testing purchases
- Production signing + ASC/Play upload/submit (owner «можно сабмитить»)
- Physical-device QA matrix (HealthKit, StoreKit, geo)
- Production deploy/secrets rotation
- RU / a11y font-scale screenshot matrix
- TalkBack manual pass

See `docs/release/ANDROID_WORKTREE_INVENTORY_V4_2026-08-24.md` and `docs/release/ANDROID_RESPONSIVE_TRUTH_2026-08-24.md`.
