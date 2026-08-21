# App Store Handoff

## App Metadata Draft
- App name: HiAir
- Subtitle: Daily air quality wellness companion
- Category: Health & Fitness
- Primary locale: en-US (RU localized in-app)
- Bundle ID: `com.hiair.app`
- Version target on this branch: `1.0` (build **188**)
- Last proven uploaded Apple build: **181** VALID / App Store 1.0 waiting-for-review context as of 2026-08-11
- Upload status for build 188: **NOT UPLOADED FROM THIS VM** (requires macOS/Xcode)
- Privacy manifest: `mobile/ios/HiAir/PrivacyInfo.xcprivacy`

## Description Draft
HiAir helps users plan daily activity around heat and air quality trends, log symptoms, and receive personalized wellness-oriented suggestions. It is a wellness support app and not a medical device.

## Keywords Draft
- air quality
- heat safety
- wellness
- symptom log
- daily planner
- allergy support

## Age Rating Notes
- No explicit content, no gambling, no user-generated public sharing.
- Health/wellness information only; no diagnosis or treatment claims.

## Permissions and Reviewer Notes
- Internet: required for environmental data and account APIs.
- Notifications: used for optional risk alerts and briefing reminders.
- Location: user-provided coordinates flow currently used; if OS location permission is enabled later, update reviewer notes.

## Test Account Placeholder
- Email: `<APP_REVIEW_TEST_EMAIL>`
- Password: `<APP_REVIEW_TEST_PASSWORD>`
- Notes: account must include at least one profile and symptom log for Insights flows.

## TestFlight Checklist
- [ ] Build and upload **188** from Xcode Organizer / Xcode Cloud on macOS.
- [ ] Attach release notes and known limitations.
- [ ] Confirm login/signup/refresh/logout flow.
- [ ] Confirm Dashboard/Planner/Insights/Symptoms/Settings.
- [ ] Confirm privacy export/delete endpoints from app.
- [ ] Confirm no blocking crashes on iPhone 15 + SE simulator baseline.

## External Blockers
- macOS/Xcode environment with signing to produce/upload build **188**.
- Apple Developer / App Store Connect roles and permissions.
- App Store Connect binary attach / submission decisions for replacing build **181** with **188**.
- Final legal wording sign-off.
