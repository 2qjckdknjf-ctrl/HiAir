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

## Account recovery reconciliation — 9 November

Read-only hiair-prod inspection matched the profile ID read from installed build 305 preferences to the Apple-login account displayed in Settings. The known historical monthly subscription belongs to that same account, not the separate email/Google account. Its stored period ended 2026-10-11 14:35:05 UTC and status is expired; no subscription row exists for the separately matched email account. No credentials, full account identifiers, or transaction IDs are included in this report. The earlier empty restoration on 5G and this historical row do not establish an active entitlement.

Correction to the earlier working hypothesis: the observed ownership-conflict message does NOT establish that the owner is currently signed into the wrong HiAir account. The exact transaction returned by the latest monthly action has not been correlated to a database owner. Targeted Cloudflare historical log searches for the verify call returned no events; this absence is not evidence that no request occurred. No purchase, account switch, ownership reassignment, entitlement grant, or database mutation was performed during this reconciliation. Remaining recovery evidence: identify the conflicting transaction from a fresh diagnostic-capable StoreKit run or Apple purchase record and verify current expiry/ownership before any repair.

## Direct Apple subscription management observation

Opened AppStore.showManageSubscriptions from installed TestFlight 305 using a UI runner without tapping purchase/renew/cancel. Initial sheet was loading; the later device screenshot `/tmp/hiair-305-management-loaded.png` shows `[Sandbox]`, HiAir Premium, subscription canceled and ended August 23, with an annual renewal offer. The renewal offer does not prove the historical subscription was annual. No active subscription was shown in this Sandbox sheet. This is not a readback of production App Store purchases. `/tmp/hiair-305-apple-subscriptions.xcresult` is an observation harness execution, not purchase or entitlement PASS.

A scoped read-only database lookup found a monthly transaction expiring August 23 in Europe/Madrid, bound to a different Apple-login account. It is a candidate for the conflict, not an exact transaction match: the installed app does not expose the transaction identifier for its failed verification. The candidate row still has stored status active but its period is in the past; it must not be treated as current entitlement. No records or ownership were changed and no renewal was initiated. Current result: no active Sandbox access to restore; precise conflicting transaction still requires direct identifier evidence.

## Recovery diagnostic candidate 306

A locally development-signed Release 306 replaced installed TestFlight 305 while preserving app data. This is NOT TestFlight verification. The local diagnostic record identified monthly transaction ending 65114, original chain ending 29827, expired 2026-10-11T14:35:05Z, associated with the current HiAir account; backend returned inactive. It does not identify the previous 305 conflict. The development-signed restore prompt names a different Apple account than the earlier TestFlight prompt, so these environments cannot be conflated. No password entered by automation, no new purchase or ownership mutation.

Added bounded (32 events), owner-separated, on-device cache diagnostics for transaction/original IDs, StoreKit app-account identifier, environment, expiry and verification outcome; no signed receipts or credentials. App Store Connect readback: latest uploaded build 305 VALID. Candidate 306 is being prepared. Targeted iOS regressions 23 passed / 0 failures (`/tmp/hiair-recovery-regression.xcresult`). Exact conflicting TestFlight transaction and both product acceptance remain pending same-environment observation.

Candidate 306 packaging follow-up: the first RU screenshot run failed because Locale.current was en_RU despite Russian app copy. Declared all five supported bundle localizations in project.yml. Repeated StoreScreenshotTests passed with observed ru_RU, app build 306, iPhone 17 Pro simulator, standard UICTContentSizeCategoryM, Reduce Motion=false and Reduce Transparency=false (`/tmp/hiair-306-ru-fixed.xcresult`, `/tmp/hiair306-ru-fixed/app-observed-environment.json`). Paywall scroll/restore/close UI regression passed (`/tmp/hiair-306-paywall-ui.xcresult`). Full unit suite before this metadata fix: 253 passed (`/tmp/hiair-306-full-unit.xcresult`). No StoreKit purchase certification follows from these checks. Added current-owner guard to prevent late diagnostic writes from another session. The earlier 98e26e60 IPA is superseded and must not be uploaded as containing this locale fix.
