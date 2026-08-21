# Store Metadata — HiAir 0.1.0-beta

**Updated:** 2026-07-07

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
| Version | 0.1.0 (13) | Bump on upload |
| Keywords | air quality, heat safety, wellness, symptom log, daily planner | Template ready |
| Description | See `APP_STORE_HANDOFF.md` | Draft |
| Review notes | See `REVIEWER_NOTES.md` | Draft |
| Review account | `APP_REVIEW_TEST_EMAIL` / password in `.env.local` | Owner: create real ASC test user |
| ASC App ID | `6773610034` | Verified via API |
| TestFlight build | Build **65** VALID (2026-07-07) | Internal testing ready |
| Screenshots | See `SCREENSHOT_CHECKLIST.md` | **MISSING** — capture on device |
| App icon 1024×1024 | `mobile/ios/.../Icon-App-1024x1024@1x.png` | Present |

## Google Play Console

| Field | Draft value | Play status |
|-------|-------------|-------------|
| App name | HiAir | LIVE in Play Console |
| Short description | Air quality & heat day planner for safer outdoor time. | Ready in GOOGLE_PLAY_HANDOFF.md |
| Full description | See `GOOGLE_PLAY_HANDOFF.md` | Draft |
| Application ID | com.hiair | Configured |
| versionCode | **188** (identity with iOS 1.0 / 188; previous internal 182) | Build locally / internal track |
| Category | Health & Fitness | Owner: select |
| Privacy policy URL | https://hiair.io/privacy/ | SET in Console |
| Data safety | See `DATA_SAFETY.md` + `PLAY_CONSOLE_QUESTIONNAIRES.md` | Draft — owner submit |
| Feature graphic | 1024×500 | UPLOADED 2026-08-11 |
| Screenshots | Phone (6) | UPLOADED 2026-08-11 — **recapture Deep Glass** |
| Content rating | IARC questionnaire | Owner |

## Materials still needed from owner

1. App Store screenshots (6.7", 6.5", 5.5" or unified set)
2. Google Play screenshots (min 2 phone)
3. Google Play feature graphic (1024×500)
4. Final legal sign-off on wellness disclaimer wording
5. Valid App Store review test account (`.test` TLD emails may fail backend validation)

## Related docs

- `docs/release/store/APP_STORE_HANDOFF.md`
- `docs/release/store/GOOGLE_PLAY_HANDOFF.md`
- `docs/release/store/PRIVACY_LABELS.md`
- `docs/release/store/DATA_SAFETY.md`


## Play progress 2026-08-11

- Internal track Active with **182** (CI `android-release` success).
- Store listing metadata + graphics uploaded via Play Developer API.
- Privacy policy URL saved in App content.
- Remaining questionnaires: content rating, target audience, data safety, advertising ID, health declaration.

## Play identity pass 2026-08-21

- Align Android **versionName 1.0 / versionCode 188** with iOS marketing 1.0 build 188.
- Listing copy rewritten to match ASC Deep Glass ASO (en-US + ru).
- Questionnaire answers: `docs/release/store/PLAY_CONSOLE_QUESTIONNAIRES.md`.
- Do **not** production-publish until owner verifies.


## ASC product page 2026-08-21

- Version **1.0** / build **187** / state **PREPARE_FOR_SUBMISSION**
- Subtitle en-US: Air quality & heat day planner; ru: Планировщик воздуха и жары
- Keywords + description + promo text rewritten for ASO (en-US + ru)
- Screenshots replaced with Deep Glass set (iPhone 6.7/6.5 + iPad 12.9) for en-US + ru
- App Preview uploaded (IPHONE_67 + IPHONE_65) stereo MOV — COMPLETE
- Evidence: `.evidence/appstore-187-testflight/asc-audit-2026-08-21/`
