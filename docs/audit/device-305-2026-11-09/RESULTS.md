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

After owner acknowledgement, the Apple prompt was observed dismissed and the paywall showed real prices (monthly EUR 5.99, yearly EUR 44.99) with Check access CTAs. A second restore again failed its 20-second entitlement assertion; subsequent screen capture confirmed a new Apple password prompt. The second monthly attempt was also blocked before the product CTA. No overlapping purchase is being started while this prompt remains. Additional evidence: `/tmp/hiair-305-restore-after-signin.xcresult`, `/tmp/hiair-305-monthly-after-signin.xcresult`, `/tmp/hiair-305-apple-prompt-repeat.png`.

After the second owner password acknowledgement, the prompt was absent and Dashboard displayed content with its live label (`/tmp/hiair-305-signin-now.png`); no elapsed useful-data measurement was obtained. A fresh restore invocation again opened Apple sign-in. The test recorded 1 failure, 0 passes, 0 skips (`/tmp/hiair-305-restore-second-signin.xcresult`); the 20-second UI assertion does not establish a backend rejection while authentication is pending. Screenshot `/tmp/hiair-305-second-restore-screen.png` confirms the system prompt. Leave this operation running for owner authentication and observe its outcome without relaunching the app or starting another restore/purchase. Build remains installed TestFlight 1.2 (305); no new app artifact installed.

Apple authentication failure was directly observed (`/tmp/hiair-305-apple-auth-error.png`). Owner switched Wi-Fi to cellular and completed the existing prompt; `/tmp/hiair-305-cellular-restore.png` shows 5G, restore enabled, Premium inactive and the explicit empty-restore result. This establishes completed empty restoration, not recovered entitlement or a diagnosed router fault. Added App Store-stage restore failure messaging in five languages and a late-owner guard in Paywall error handling. Simulator regression: 22 passed, 0 failed/skipped on iPhone 17 Pro iOS 26.5 (`/tmp/hiair-305-store-auth-regression.xcresult`). These code changes are not in installed build 305.

Monthly on 5G: the test reached and tapped the real monthly Subscribe CTA, but no confirmed Premium within 120 seconds. Final hierarchy contains `Purchase is already linked to another account.` (`/tmp/hiair-305-monthly-cellular.xcresult`, exported final hierarchy under `/tmp/hiair-305-monthly-cellular-attachments/`). This is a distinct server ownership conflict after Apple network authentication recovered, not a successful monthly purchase. Backend rejects transactions bound to another user in `subscription_repository.py`; no ownership records changed. Yearly attempt deferred pending clarification of the original HiAir account, to avoid treating another purchase as recovery. Added localized ownership-recovery copy in all five languages; installed build 305 remains unchanged.

Ownership recovery regression: 23 tests passed, 0 failed (SubscriptionServiceTests + SessionLogoutIsolationTests); `/tmp/hiair-305-owner-error-regression-2.xcresult`. This does not certify purchases or ownership migration.
