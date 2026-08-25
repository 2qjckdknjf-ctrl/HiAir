# Android Responsive Hardening Truth — 2026-08-24 (final)

**Verdict:** `CODE-READY / EXTERNAL ACTIONS REQUIRED`  
**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Worktree:** `/Users/alex/Projects/HIAir-store-ready`  
**RC base:** `002dc60d` + commits `b9e04bd0…a2d6da7d` (tracked tree clean after docs commit)

## Truth states (do not conflate)

| Artifact | Semantic | Shelf | Visual | Applies to committed code? |
|----------|----------|-------|--------|----------------------------|
| `dev-20260824-v4-visual-3` | 12/12 PASS | 12/12 PASS | **2/12 PASS** | **No** — frozen historical |
| `dev-20260824-v4-visual-4` | 12/12 PASS | 12/12 PASS | **6/12 PASS** | **No** — stale |
| `dev-20260825-v4-visual-4b` | 12/12 PASS | 12/12 PASS | **9/12 PASS** | **No** — superseded |
| `dev-20260825-v4-visual-4c` | **12/12 PASS** | **12/12 PASS** | **12/12 PASS** | **Yes** — matches committed presentation |
| `20260825-phone-en-v4c-v3` | **8/8 PASS** | **8/8 PASS** | **8/8 PASS** | **Yes** — phone matrix with shelf crop |
| `20260825-tablet-en-v4c` | **8/8 PASS** | **8/8 PASS** | **8/8 PASS** | **Yes** — tablet matrix with shelf crop |
| `20260825-phone-en-v4c` | 8/8 PASS | PASS | **PENDING** | **No** — superseded by v4c-v3 |

## Verification (complete)

| Check | Result |
|-------|--------|
| `assembleDebug` / `bundleRelease` | **PASS** |
| JVM unit tests | **PASS** |
| `lintDebug` | **PASS** |
| `compileDebugAndroidTestSources` | **PASS** |
| `test_android_capture_shelf.py` | **PASS** (6/6) |
| `test_android_capture_manifest.py` | **PASS** (11/11) |
| Device gates (geometry, cold-start) | **PASS** (21/21 — `.evidence/android-device-gates/20260825-post-commit-v2/`) |
| Targeted visual v4c | **SEMANTIC 12/12 + VISUAL 12/12** |
| Full Phone EN capture | **SEMANTIC 8/8 + VISUAL 8/8** |
| Full Tablet EN capture | **SEMANTIC 8/8 + VISUAL 8/8** |
| Geometry matrix | **PASS** (8/8 — `20260825-post-commit-v4`) |

## Root cause fixes (closed)

| Issue | Fix |
|-------|-----|
| Instrumentation hang (0/14 forever) | Removed recursive `navShell.post { updateResponsiveChrome() }`; one-shot layout listener |
| Store-shot bootstrap extras | `StoreScreenshotBootstrap` bundle flag/string parsing |
| Empty body after layout pass | Layout-safe store-shot commit pass |
| False-positive readiness | `StoreScreenshotReadiness.publish()` content validation |
| Launcher shelf in `*.app.png` | `android_capture_shelf.py` + regression fixtures |
| manifest/visual-review drift | `sync_android_visual_manifest.py` |
| Onboarding portrait void | `fillViewport` + `viewportCenteredHost` |
| Planner/symptoms nav overlap | Tight store viewport compression |

## Atomic commits

1. `b9e04bd0` — `fix(android-capture): enforce app-window crop and shelf truth`
2. `68c4eb65` — `test(android-capture): add shelf and provenance regression fixtures`
3. `365db4fb` — `fix(android-v4): balance responsive store-screen composition`
4. `0906f1a3` — `fix(android-ui): enforce measured navigation clearance`
5. `a2d6da7d` — `test(android-ui): verify cold-start reflow and scroll clearance`
6. *(docs commit)* — `docs(release): align Android visual evidence and readiness truth`

## Provenance

- `rc_source_sha`: `7d90e5df` in `docs/release/RC_PROVENANCE_MANIFEST_2026-08-25.json`
- `.evidence/` remains gitignored output; paths referenced in RC manifest `evidence_runs`

## External next

1. Push branch + PR (owner network)
2. Physical Sandbox IAP verification
3. RU + a11y screenshot matrix
4. ASC/Play submit after owner «можно сабмитить»
