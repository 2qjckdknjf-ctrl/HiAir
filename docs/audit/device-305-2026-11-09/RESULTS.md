# Physical TestFlight 305 — 9 November 2026

Source candidate: `18f8353d8b26cd3bc71a372628f7c11942623c31` (PR98).
Device: physical iPhone 17 Pro, iOS 27.2 (24B119), RU interface.
Initial installed build was 304; owner updated through TestFlight. `devicectl` readback confirmed 1.2 (305).
Only the XCTest runner was installed by this task. `UseDestinationArtifacts=true` runs against the existing app; no mock API or local StoreKit configuration is used.

## Observed results (not certification)

- Live `/api/health`: HTTP 200, 0.734401s from Mac. API SHA `3ac1596ee8dc9ffdf6555958a2c373fbb585ce1c`. This is not iPhone useful-data latency.
- Insights primary-content test: 1 executed, 1 failed, 0 skipped. The attached hierarchy shows Premium-required and `insights.primary.unavailable`; this failure does not establish an 8-second network stall.
- Restore test: 1 executed, 1 failed, 0 skipped. No confirmed restoration within 20 seconds. Restore button remained disabled. Subsequently observed the Apple account password prompt, which persisted across app restart. Therefore recovery is blocked on Apple authentication, not proven backend rejection.
- Monthly purchase attempt: blocked by the same SpringBoard Apple authentication prompt before the paywall could be exercised. No purchase success claimed.
- Yearly purchase: not yet executed; must follow authentication without overlapping a StoreKit operation.
- ASC read-only diagnostic: both `com.hiair.premium.monthly` and `com.hiair.premium.yearly` APPROVED; availability and price records present.
- Dashboard screenshot showed cached content, not a live-refresh timing result.

## Evidence (local; may contain account/location data, not committed)

- `/tmp/hiair-305-runtime-installed.xcresult`
- `/tmp/hiair-305-restore-installed.xcresult`
- `/tmp/hiair-305-monthly.xcresult`
- `/tmp/hiair-305-apple-prompt.png`
- `/tmp/hiair-305-installed.xctestrun`

## Fix in progress

Expose service-owned restore phases in Settings and Paywall: reading store → waiting for Apple sign-in → verifying access. Attribute progress to the initiating owner and reject stale Settings failure updates after account switch. This is not a substitute for successful restore.

## Next action

Owner completes the system Apple sign-in on iPhone (no password in chat). Then rerun restore, exercise monthly and yearly separately with actual Apple confirmation, verify server-confirmed entitlement and paid Insights, and measure Dashboard live useful-data latency. Preserve the installed TestFlight app while collecting baseline evidence. Current verdict: DEVICE ACCEPTANCE INCOMPLETE.

Local follow-up verification: SubscriptionServiceTests and SessionLogoutIsolationTests — 21 executed, 0 failures. Evidence: `/tmp/hiair-305-restore-phase-tests.xcresult`. Physical purchase/restore acceptance remains blocked on Apple sign-in.
