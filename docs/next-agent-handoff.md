# Next agent handoff — HiAir 1.0 ship line

## Current state

- **Working branch for ship PR:** `cursor/ship-hiair-1-0-188-00f2` from `design/redesign-v4-deep-glass`
- **Merge target:** `main` (live history). Repo default branch is still stale and should be corrected by owner in GitHub settings, not by automation here.
- **Android release identity:** **1.0 (188)** on this branch and already uploaded to **Play Internal** today via CI run `32485234454` (`hiair-android-1.0` artifact / Play internal 188 context in handoff docs).
- **iOS release identity:** now aligned in code to **1.0 (188)** (`project.yml` + `HiAir.xcodeproj/project.pbxproj`); no TestFlight 188 upload was attempted from this Linux VM.
- **Last proven iOS binary:** TestFlight / App Store build **181** was the last known valid upload on 2026-08-11; App Store 1.0 was waiting for review on build 181 per operator context.
- **Backend/API:** no production backend rewrite in this pass; release API remains `https://api.hiair.io`.

## What changed in this pass

1. Aligned iOS build number source-of-truth from **181** to **188** in the tracked Xcode sources.
2. Updated `scripts/release/validate_store_release_builds.sh` so the iOS release gate checks for build **188**, not stale build **13**.
3. Refreshed ship docs/handoff to the current truthful state:
   - Android internal track **188** live today
   - iOS code aligned to **188**
   - last proven TestFlight remains **181**
   - TestFlight/App Store/console/legal tasks remain owner-only

## Required next steps (owner / Mac / console)

1. Run iOS CI / Xcode build from a **macOS** runner or local Mac and confirm build settings expand to **1.0 (188)**.
2. Archive and upload **iOS build 188** to TestFlight from Xcode/Xcode Cloud or a Mac with signing access.
3. In App Store Connect, attach the uploaded **188** binary to the 1.0 submission if the owner intends to replace build 181.
4. Finish owner-only store tasks:
   - Play Console questionnaires: content rating / data safety / target audience / health declarations (#6)
   - legal sign-off (#4)
   - secrets governance sign-off (#5)
5. Run physical device QA on release binaries; do not claim device certification from simulator/CI-only evidence.

## Do not

- Claim TestFlight **188** exists until a real macOS/Xcode upload happens
- Claim Store Sandbox Ready or Production Ready without real device / store evidence
- Change GitHub default branch automatically from this repo without explicit owner approval

## Docs

- `docs/07_STORE_HANDOFF.md`
- `docs/08_KNOWN_GAPS.md`
- `docs/release/store/APP_STORE_HANDOFF.md`
- `docs/release/store/GOOGLE_PLAY_HANDOFF.md`
- `docs/release/store/STORE_METADATA.md`
