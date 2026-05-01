# App Store Handoff

## App Metadata Draft
- App name: HiAir
- Subtitle: Daily air quality wellness companion
- Category: Health & Fitness
- Primary locale: en-US (RU localized in-app)
- Bundle ID: `com.hiair.app`
- Version: `0.1.0` (build number managed in Xcode target settings)

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
- [ ] Upload build from Xcode Organizer.
- [ ] Attach release notes and known limitations.
- [ ] Confirm login/signup/refresh/logout flow.
- [ ] Confirm Dashboard/Planner/Insights/Symptoms/Settings.
- [ ] Confirm privacy export/delete endpoints from app.
- [ ] Confirm no blocking crashes on iPhone 15 + SE simulator baseline.

## External Blockers
- Apple Developer account roles/permissions.
- App Store Connect metadata submission.
- Final legal wording sign-off.
