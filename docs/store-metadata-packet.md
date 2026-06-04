# HiAir Store Metadata Packet (Draft)

Last updated: 2026-04-18

Use this file as the single packet for App Store Connect and Google Play metadata preparation.

## 1) Core identity

- App name: `HiAir`
- Subtitle/short description (draft): `Heat & Air Wellness Companion`
- Category candidates: `Health & Fitness`, `Weather`
- Support URL: `[TBD]`
- Privacy policy URL: `[TBD - final legal URL]`

## 2) Marketing descriptions

### Full description (draft)

HiAir helps you understand daily heat and air-quality conditions and adapt your routine.
Get profile-based risk insights, practical recommendations, and optional alert notifications.
HiAir is a wellness support tool and does not provide medical diagnosis.

### What's new template

- Improved risk consistency and recommendation reliability.
- Strengthened privacy export/delete flows.
- Migrated account/session stack to Supabase Auth with secure token refresh.
- Stability and quality updates across iOS and Android.

## 3) Screenshot matrix

### iOS required set

- [ ] 6.7" display screenshots (minimum required set)
- [ ] 6.5"/5.5" if needed by current App Store policy
- [ ] Core screens captured:
  - [ ] onboarding/auth
  - [ ] dashboard risk summary
  - [ ] daily planner/safe windows
  - [ ] recommendations detail
  - [ ] settings/privacy controls

### Android required set

- [ ] Phone screenshots (minimum required count)
- [ ] 7"/10" tablet screenshots if distribution requires it
- [ ] Core screens captured:
  - [ ] onboarding/auth
  - [ ] dashboard risk summary
  - [ ] planner
  - [ ] recommendations
  - [ ] settings/privacy

## 4) Privacy label mapping (working draft)

| Data type | Used in product | Purpose | User deletion support |
|---|---|---|---|
| Email/Supabase auth id | yes | account auth/session | yes |
| Profile sensitivity/location | yes | personalized risk computation | yes |
| Symptom logs | yes | recommendation personalization | yes |
| Health activity summaries (steps, heart rate aggregates) | optional (consent) | personal load / wellness risk context | yes (`DELETE /api/v1/wearables/data`) |
| Risk/recommendation history | yes | user history and guidance | yes |
| Device token | optional | push notifications | yes |
| Delivery attempts / webhook / rotation ops logs | ops only | reliability/security auditing | partial (retention policy) |

## 5) Reviewer notes template

- This app provides wellness guidance based on environmental risk indicators.
- No medical diagnosis or treatment claims are made.
- Demo account / test credentials:
  - email: `[TBD]`
  - password: `[TBD]`
- Backend environment for review: `[TBD]`

## 6) Finalization checklist

- [ ] Legal reviewed privacy policy and terms wording.
- [ ] Final URLs inserted (support/privacy).
- [ ] Screenshot set exported and archived with date/version.
- [ ] Store descriptions localized as required.
- [ ] Privacy label answers reviewed by legal/security owner.
- [ ] **App Store Privacy Labels:** Health (Fitness) — steps, heart rate — linked to user, not used for tracking.
- [ ] **Google Play Data Safety:** Health & fitness — collected with consent, encrypted in transit, deletable.
- [ ] Health permission purpose strings verified (iOS `NSHealthShareUsageDescription`, Android Health Connect rationale).
- [ ] No misleading medical claims in store copy.
- [ ] Packet signed off by product + release owner.
