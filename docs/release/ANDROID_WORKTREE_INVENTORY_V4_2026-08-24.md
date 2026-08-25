# Android Store-Ready Worktree Inventory — 2026-08-24 (v4 pass)

**Worktree:** `/Users/alex/Projects/HIAir-store-ready`  
**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Baseline HEAD:** `002dc60dd87fc77869d0f7644a6c4e7c9008746b`  
**Inventory captured:** 2026-08-25 (post 6-commit local closure)

## Truth separation (mandatory)

| State | Semantic | Shelf | Visual | Applies to committed code? |
|-------|----------|-------|--------|----------------------------|
| `dev-20260825-v4-visual-4c` | **12/12 PASS** | **12/12 PASS** | **12/12 PASS** | **Yes** |
| `20260825-phone-en-v4c` | **8/8 PASS** (semantic) | **PASS** | **PENDING** | **Yes** |
| Prior catalogs (v3/v4/4b) | PASS | PASS | 2–9/12 visual | **No** — frozen/stale |

All presentation + capture tooling committed in 6 atomic commits (`b9e04bd0…a2d6da7d`).

## Path count

~66 paths (27 modified tracked + 39 untracked). No accidental APK/AAB/build intermediates in git status; `.evidence/` is intentional capture output.

## Capture tooling (11)

- `scripts/ops/android_capture_lib.py` (M)
- `scripts/ops/android_capture_validate.py` (M)
- `scripts/ops/android_capture_persist_evidence.py` (??)
- `scripts/ops/android_capture_shelf.py` (??)
- `scripts/ops/sync_android_visual_manifest.py` (??)
- `scripts/ops/generate_android_visual_review.py` (??)
- `scripts/ops/run_android_targeted_visual_smoke.sh` (??)
- `scripts/ops/run_android_device_gates.sh` (??)
- `scripts/ops/test_android_capture_shelf.py` (??)
- `scripts/ops/fixtures/android_capture_shelf/` (??)

## Tests / fixtures (10)

- `mobile/android/app/src/androidTest/java/com/hiair/HiAirGeometryTestSupport.kt` (??)
- `mobile/android/app/src/androidTest/java/com/hiair/RootShellLayoutGeometryTest.kt` (??)
- `mobile/android/app/src/androidTest/java/com/hiair/StoreScreenshotColdStartOnboardingTest.kt` (??)
- `mobile/android/app/src/androidTest/java/com/hiair/StoreScreenshotColdStartPaywallTest.kt` (??)
- `mobile/android/app/src/androidTest/java/com/hiair/StoreScreenshotColdStartSymptomsTest.kt` (??)
- `mobile/android/app/src/androidTest/java/com/hiair/StoreScreenshotResponsiveGeometryTest.kt` (M)
- `mobile/android/app/src/test/java/com/hiair/ui/design/HiAirGridLayoutTest.kt` (??)
- `mobile/android/app/src/test/java/com/hiair/ui/design/HiAirWindowLayoutTest.kt` (??)
- `scripts/ops/run_android_geometry_matrix.sh` (??)

## Presentation / layout (32)

- `AppMainActivity.kt`, renderers (`Dashboard*`, `Planner*`, `Onboarding*`, `Paywall*`, `Settings*`, `Symptoms*`, `Main*`, `Insights*`, `FirstRun*`)
- Design system: `HiAirV4Glass.kt`, `HiAirV4Presentation.kt`, `HiAirNavClearance.kt`, `HiAirAdaptiveLayout.kt`, `HiAirResponsiveLayout.kt`, `HiAirGridLayout.kt`, `HiAirWindowLayout.kt`, `HiAirComponents.kt`, `HiAirLiquidGlass.kt`, `HiAirRiskGaugeView.kt`, `ContentMeasuredGlassFrameLayout.kt`, `HiAirGeometryTags.kt`
- `PlannerHourlyChartView.kt`
- Drawables: `ic_v4_*.xml` (10)
- `AndroidL10n.kt`

## Infrastructure (readiness / geometry — semantics frozen) (4)

- `StoreScreenshotReadiness.kt` (??)
- `StoreScreenshotBootstrap.kt` (M)
- `HiAirGeometryMarkers.kt` (??)
- `RenderContext.kt` (M)

## Docs (3)

- `docs/release/STORE_READY_STATUS_2026-08-24.md` (M)
- `docs/release/ANDROID_RESPONSIVE_TRUTH_2026-08-24.md` (??)
- `docs/release/store/ANDROID_VISUAL_PASS_CONTRACT.md` (??)

## Evidence (untracked)

- `.evidence/android-targeted-visual/dev-20260825-v4-visual-4c/` — **current** semantic+shelf+visual 12/12
- `.evidence/android-targeted-visual/dev-20260825-v4-visual-4b/` — superseded (9/12 visual)
- `.evidence/android-targeted-visual/dev-20260824-v4-visual-3/` — frozen historical
- `.evidence/android-device-gates/20260825-post-commit-v2/` — 21/21 PASS (committed code)

## Possibly unrelated — verify before commit (4)

- `mobile/android/app/build.gradle.kts` (M) — screenshot/test deps only expected
- `mobile/android/app/src/main/AndroidManifest.xml` (M) — store-shot intent filters only expected
- `mobile/android/app/src/main/java/com/hiair/ui/DashboardViewModel.kt` (M) — confirm no business-logic drift
- `mobile/android/app/src/main/java/com/hiair/ui/settings/SettingsState.kt` (M) — confirm presentation-only

## Binary / build output check

`git status --porcelain` contains **no** `build/`, `*.apk`, `*.aab`, or `.gradle/` paths. PNG evidence lives only under `.evidence/`.
