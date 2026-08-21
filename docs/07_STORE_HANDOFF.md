# 07 Store Handoff

Store handoff packet lives in:
- `docs/release/store/APP_STORE_HANDOFF.md`
- `docs/release/store/GOOGLE_PLAY_HANDOFF.md`
- `docs/release/store/PRIVACY_LABELS.md`
- `docs/release/store/DATA_SAFETY.md`
- `docs/release/store/REVIEWER_NOTES.md`
- `docs/release/store/WELLNESS_DISCLAIMER.md`
- `docs/release/store/BETA_TESTING_PLAN.md`
- `docs/release/store/SCREENSHOT_CHECKLIST.md`
- `docs/release/store/RELEASE_NOTES.md`

Status: Ship packet refreshed for the HiAir 1.0 line.

Current release truth:
- Android **1.0 (188)** is already on Play Internal (2026-08-21 CI / console handoff context).
- iOS source-of-truth is now aligned in code to **1.0 (188)**, but the last proven uploaded Apple binary is still **181**.
- TestFlight/App Store upload of iOS **188** requires a real Mac/Xcode environment and owner signing access.
- Remaining owner-only work: Play questionnaires/data safety/target audience, legal sign-off, secrets governance sign-off.
