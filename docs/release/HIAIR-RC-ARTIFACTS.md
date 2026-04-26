# HiAir Closed Beta RC artifacts (canonical inventory)

RC label: **`closed-beta-rc1`** (increment to `rc2` only when owner intentionally cuts a new candidate).

## Android

| Artifact | Path |
| --- | --- |
| Release AAB | `mobile/android/app/build/outputs/bundle/release/app-release.aab` |
| Debug APK | `mobile/android/app/build/outputs/apk/debug/app-debug.apk` |
| Lint report | `mobile/android/app/build/reports/lint-results-debug.html` |

**Build command (evidence):**

```bash
cd mobile/android
./gradlew clean assembleDebug assembleRelease bundleRelease lint
```

## iOS

| Artifact | Path |
| --- | --- |
| Simulator build | DerivedData output (local); gate command uses `iphonesimulator` |
| Release archive | `mobile/ios/build/HiAir.xcarchive` |
| Exported IPA | `mobile/ios/build/HiAir.ipa` |

**Simulator compile gate:**

```bash
cd mobile/ios
xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
```

**IPA:** Producing an IPA is **BLOCKED_EXTERNAL** without Apple signing credentials — see `docs/release/IOS-TESTFLIGHT-RC-UPLOAD-STEPS.md`. Do not commit signing assets.

## Machine-readable manifest

```bash
python3 mobile/scripts/generate_release_manifest.py --strict
# or Closed Beta RC footer explicitly:
python3 mobile/scripts/generate_release_manifest.py --rc
```

Output: `docs/release-artifacts-manifest.md`

## Backend evidence (2026-04-26)

| Check | Command | Result |
| --- | --- | --- |
| Postgres | `pg_isready -h localhost -p 5432` | accepting connections |
| Tests | `cd backend && ../.venv/bin/python -m pytest -q` | `36 passed` |
| Smoke | `cd backend && PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | DB smoke OK; run API separately for preflight |
| API + preflight | `uvicorn` + `scripts/beta_preflight.py` | `Preflight passed.` |

## Release notes draft (RC)

- Engineering: backend tests green; local Postgres smoke green; API preflight green; iOS simulator build green; Android `bundleRelease` + lint green.
- Push: client registration hardened with structured logs; live delivery remains credential- and device-dependent.
- Known external gates: TestFlight upload, Play Internal upload, legal/signoff, ops ownership, WAF/rate-limit evidence.
