# Store Metadata — HiAir 1.0 ship line

**Updated:** 2026-08-21

## URLs (live)

| Field | Value | Status |
|-------|-------|--------|
| Privacy Policy | https://hiair.io/privacy/ | LIVE |
| Terms of Service | https://hiair.io/terms/ | LIVE |
| Marketing / Support | https://hiair.io | LIVE |
| Support email | hello@hiair.io | LIVE |
| API (release builds) | https://api.hiair.io | LIVE |

## App Store Connect

| Field | Draft value | ASC status |
|-------|-------------|------------|
| App name | HiAir | LIVE in Play Console in ASC |
| Subtitle | Daily air quality wellness companion | Template ready |
| Category | Health & Fitness | Owner: select |
| Bundle ID | com.hiair.app | Configured |
| Version | 1.0 (188 target on this branch) | Code aligned; upload still required |
| Keywords | air quality, heat safety, wellness, symptom log, daily planner | Template ready |
| Description | See `APP_STORE_HANDOFF.md` | Draft |
| Review notes | See `REVIEWER_NOTES.md` | Draft |
| Review account | `APP_REVIEW_TEST_EMAIL` / password in `.env.local` | Owner: create real ASC test user |
| ASC App ID | `6773610034` | Verified via API |
| TestFlight build | Build **181** last proven VALID (2026-08-11) | Build **188** not uploaded from this VM |
| Screenshots | See `SCREENSHOT_CHECKLIST.md` | **MISSING** — capture on device |
| App icon 1024×1024 | `mobile/ios/.../Icon-App-1024x1024@1x.png` | Present |

## Google Play Console

| Field | Draft value | Play status |
|-------|-------------|-------------|
| App name | HiAir | LIVE in Play Console |
| Short description | Air quality & heat day planner for safer outdoor time. | Ready in GOOGLE_PLAY_HANDOFF.md |
| Full description | See `GOOGLE_PLAY_HANDOFF.md` | Draft |
| Application ID | com.hiair | Configured |
| versionCode | **188** (identity with iOS 1.0 / 188) | Internal track live on 2026-08-21 |
| Category | Health & Fitness | Owner: select |
| Privacy policy URL | https://hiair.io/privacy/ | SET in Console |
| Data safety | See `DATA_SAFETY.md` + `PLAY_CONSOLE_QUESTIONNAIRES.md` | Draft — owner submit |
| Feature graphic | 1024×500 | UPLOADED 2026-08-11 |
| Screenshots | Phone (6) | UPLOADED 2026-08-11 — **recapture Deep Glass** |
| Content rating | IARC questionnaire | Owner |

## Materials still needed from owner

1. App Store screenshots / final ASC asset confirmation
2. App Store build **188** upload from macOS/Xcode
3. Play Console questionnaires: content rating, data safety import, target audience / health declarations
4. Final legal sign-off on wellness disclaimer wording
5. Secrets governance sign-off
6. Valid App Store review test account (`.test` TLD emails may fail backend validation)

## Related docs

- `docs/release/store/APP_STORE_HANDOFF.md`
- `docs/release/store/GOOGLE_PLAY_HANDOFF.md`
- `docs/release/store/PRIVACY_LABELS.md`
- `docs/release/store/DATA_SAFETY.md`


## Play progress 2026-08-21

- Internal track active with **1.0 (188)** (CI run `32485234454` / artifact `hiair-android-1.0`).
- Store listing metadata + graphics already present in Console.
- Privacy policy URL saved in App content.
- Remaining questionnaires: content rating, target audience / health, data safety import and final review.

## Play identity pass 2026-08-21

- Align Android **versionName 1.0 / versionCode 188** with iOS marketing 1.0 build 188.
- Listing copy rewritten to match ASC Deep Glass ASO (en-US + ru).
- Questionnaire answers: `docs/release/store/PLAY_CONSOLE_QUESTIONNAIRES.md`.
- Do **not** production-publish until owner verifies.


## ASC / TestFlight truth 2026-08-21

- Code on this branch now targets **1.0 (188)** for iOS.
- Last proven Apple upload remains **181** (VALID on 2026-08-11).
- This Linux VM cannot archive/upload IPA to TestFlight; a **Mac/Xcode** path is required for build **188**.
- If owner wants the redesign line in review, upload **188** and attach that binary in App Store Connect instead of assuming older ASC state is still current.
