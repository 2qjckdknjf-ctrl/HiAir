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
| App name | HiAir | Owner: verify in ASC |
| Subtitle | Daily air quality wellness companion | Template ready |
| Category | Health & Fitness | Owner: select |
| Bundle ID | com.hiair.app | Configured |
| Version | 0.1.0 (13) | Bump on upload |
| Keywords | air quality, heat safety, wellness, symptom log, daily planner | Template ready |
| Description | See `APP_STORE_HANDOFF.md` | Draft |
| Review notes | See `REVIEWER_NOTES.md` | Draft |
| Review account | `APP_REVIEW_TEST_EMAIL` / password in `.env.local` | Owner: create real ASC test user |
| Screenshots | See `SCREENSHOT_CHECKLIST.md` | **MISSING** — capture on device |
| App icon 1024×1024 | `mobile/ios/.../Icon-App-1024x1024@1x.png` | Present |

## Google Play Console

| Field | Draft value | Play status |
|-------|-------------|-------------|
| App name | HiAir | Owner: verify |
| Short description | Plan daily activity around air quality and heat risk. | Draft |
| Full description | See `GOOGLE_PLAY_HANDOFF.md` | Draft |
| Application ID | com.hiair | Configured |
| versionCode | 2 | Ready |
| Category | Health & Fitness | Owner: select |
| Privacy policy URL | https://hiair.io/privacy/ | Ready |
| Data safety | See `DATA_SAFETY.md` | Draft — owner submit |
| Feature graphic | 1024×500 | **MISSING** |
| Screenshots | Phone + optional 7" tablet | **MISSING** |
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
