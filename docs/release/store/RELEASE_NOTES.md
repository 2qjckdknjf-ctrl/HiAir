# Release Notes (Draft)

## HiAir 0.1.0-beta

### Highlights
- Auth hardening with refresh token rotation and session expiry handling.
- Aurora Calm v2 visuals extended to iOS auth/onboarding.
- Personal Patterns insights and Morning Briefing APIs integrated.
- Backend security checks and release gate automation improved.

### Security and Reliability
- Protected environment fails fast on insecure runtime auth settings.
- Admin endpoint access policy tightened.
- Added webhook signature regression tests.
- Added final cross-platform release gate script.

### Known Limits
- Live push delivery requires external APNs/FCM production credentials.
- Store/legal metadata remains draft until owner/legal sign-off.
