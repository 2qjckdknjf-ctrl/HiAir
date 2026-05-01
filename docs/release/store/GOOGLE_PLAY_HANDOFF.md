# Google Play Handoff

## Listing Metadata Draft
- App name: HiAir
- Short description: Plan daily activity around air quality and heat risk.
- Full description: HiAir provides wellness-focused daily planning based on environmental signals and user symptom logs. Includes alerts, personalized insights, and morning briefings.
- Category: Health & Fitness
- Application ID: `com.hiair`

## Data Safety Draft
- Collects account email and user-submitted wellness data.
- Data used for app functionality and personalization.
- Data export and delete endpoints available in backend API.
- No claim of selling personal data.

## Content Rating Notes
- Non-violent, non-sexual, non-gambling.
- Health/wellness guidance only; not emergency/diagnostic software.

## Testing Track Checklist
- [ ] Internal testing track upload (AAB/APK).
- [ ] 20-50 closed beta testers assigned.
- [ ] Validate login/session refresh/logout.
- [ ] Validate notification permission flow on Android 13+.
- [ ] Validate release build with HTTPS API endpoint.

## App Access Notes
- If auth-gated review is required, provide review credentials:
  - Email: `<PLAY_REVIEW_TEST_EMAIL>`
  - Password: `<PLAY_REVIEW_TEST_PASSWORD>`

## External Blockers
- Google Play Console access.
- Production signing key handling outside git.
- Final policy/legal review.
