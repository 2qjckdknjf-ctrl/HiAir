# Invalid Android Store Screenshot Capture Runs — 2026-08-24

**Verdict for these runs:** `FAIL / EVIDENCE INVALID`  
**Do not use for store readiness, visual comparison PASS, or RC provenance until replaced with semantically validated captures.**

These directories are preserved as **failure evidence**. They must not be deleted, silently overwritten, or cited as PASS.

## Root causes (pipeline)

| Issue | Impact |
|-------|--------|
| Reused arbitrary booted emulator (`adb devices` first match) | Wrong device class / mixed phone-tablet |
| No `-s <serial>` isolation | Commands hit wrong device |
| No foreground-package check | Launcher screenshots saved as success |
| No UI hierarchy / crash-dialog validation | Crash ANR dialogs saved as success |
| `FONT_SCALE` recorded but never applied | Manifest lied about observed typography |
| 3s fixed sleep | App not ready or already crashed |
| PNG existence only | Semantic invalid frames counted PASS |

## Invalid runs

### Phone EN — `.evidence/android-screenshots/2026-08-24-phone-en/`

| File | Expected | Invalid reason |
|------|----------|----------------|
| `01-dashboard.png` | Dashboard | **Marginal** — may show app; not re-validated under fixed pipeline |
| `02-planner.png` | Planner | **System crash dialog** (app crash during Planner open) |
| `03-insights.png` | Insights | **Load error state** (network/API failure UI, not success capture) |
| `04-symptoms.png` | Symptoms | **Connection/load error** (taxonomy fetch failure UI) |
| `05-settings.png` | Settings | **Android launcher** (HiAir not foreground) |
| `06-paywall.png` | Paywall | **Android launcher** |
| `07-onboarding.png` | Onboarding | **Android launcher** |
| `08-navigation-shell.png` | Navigation shell | **Android launcher** |

Manifest: `.evidence/android-screenshots/2026-08-24-phone-en/capture-manifest.json`  
Status: **INVALID** — pipeline accepted PNGs without semantic gates.

### Tablet EN — `.evidence/android-screenshots/2026-08-24-tablet-en/`

| File | Expected | Invalid reason |
|------|----------|----------------|
| `01-dashboard.png` | Dashboard | **Wrong screen** (not canonical dashboard success state) |
| `02-planner.png` | Planner | Not re-validated; prior pipeline unreliable |
| `03-insights.png` | Insights | Not re-validated; prior pipeline unreliable |
| `04-symptoms.png` | Symptoms | Not re-validated; prior pipeline unreliable |
| `05-settings.png` | Settings | **Android launcher** |
| `06-paywall.png` | Paywall | **System crash dialog** |
| `07-onboarding.png` | Onboarding | **Android launcher** |
| `08-navigation-shell.png` | Navigation shell | **Android launcher** |

Manifest: `.evidence/android-screenshots/2026-08-24-tablet-en/capture-manifest.json`  
Status: **INVALID** — pipeline accepted PNGs without semantic gates.

## Replacement criteria

New captures must pass the rewritten `scripts/ops/capture_android_screenshots.sh` gates:

- Dedicated AVD → serial for entire run
- All `adb` via `-s <serial>`
- Foreground `com.hiair` before screencap
- Unique screen root accessibility marker per frame
- No crash/ANR/launcher/splash/error-in-success-state
- Hierarchy XML + logcat slice + requested/observed environment per PNG
- Manual visual review of all 16 primary PNGs (8 phone + 8 tablet)

## Related invalid claims (corrected in matrix)

- Android phone/tablet matrix: was **PASS** → **FAIL / EVIDENCE INVALID**
- Android Deep Glass parity: remains **PARTIAL** (not complete from invalid shots)
- RU / TalkBack manual: **PENDING**
