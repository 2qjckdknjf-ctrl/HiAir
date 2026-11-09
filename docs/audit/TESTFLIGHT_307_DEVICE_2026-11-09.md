# TestFlight 307: device verification and restore follow-up

## Installed application

On 9 November 2026 (Europe/Madrid), iPhone 17 Pro / iOS 27.2 (24B119), cellular 5G, Russian HiAir UI. The first device read still identified an Apple Development build numbered 307. TestFlight visibly offered Install; after the owner installed it, installation-proxy readback confirmed **1.2 (307), TestFlight Beta Distribution, get-task-allow=false, beta-reports-active=true**, and a changed application bundle path. CoreDevice's builtByDeveloper flag remained true and was not used to certify distribution. No app data was deleted.

Metadata: `/tmp/hiair-307-testflight-origin-final.json`. Source/IPA receipt remains [307 release manifest](../release/RELEASE_MANIFEST_307_2026-11-09.json). Test runner updates did not replace the installed TestFlight application.

## Observed postconditions

| Scenario | Observed result | Evidence |
| --- | --- | --- |
| Dashboard | Real visible risk value (20), no profile-bootstrap error; launch-to-visible-risk **8.362581s**, one sample. This is not a p95 or a new live-provider latency measurement. | `/tmp/hiair-307-testflight-recovery-verified.xcresult`, latency/hierarchy/screenshot attachments |
| Health | Connected state after consent flow; server readback confirmed consent at **20:38:08.733679 UTC** and daily aggregate update at **20:38:14.720595 UTC**, 11 daily rows. Scope unchanged; no raw health values exported. | Same xcresult (2 passed, 0 failed/skipped); read-only production SQL |
| Monthly catalog | Actual StoreKit price **5.99 EUR**, one-month period visible. Purchase button was not tapped. | `/tmp/hiair-307-testflight-catalog.xcresult` |
| Yearly catalog | Actual StoreKit price **44.99 EUR**, one-year period visible. Purchase button was not tapped. | Same catalog result (1 passed, 0 failed/skipped) |
| Restore | **FAILED acceptance:** remained in readingStore / “Восстановление…” beyond the 120-second observation deadline, with no final outcome. This was not an Apple password prompt. | `/tmp/hiair-307-testflight-restore.xcresult` and `/tmp/hiair-307-restore-current-screen.png` |
| Apple subscription management | System Sandbox screen showed canceled/expired HiAir subscription, ended **23 August (year not shown)**, with an annual renewal offer. No renewal/cancel/plan-change action was taken. Opening this screen does not prove restoration. | `/tmp/hiair-307-testflight-apple-status.xcresult`, full-screen attachment |
| Follow-up restore | Test was interrupted when another app took the foreground; kAXErrorServerNotFound is not a second completed acceptance result. Returning to HiAir later still showed the in-progress restore. | `/tmp/hiair-307-testflight-restore-after-apple-status.xcresult`; `/tmp/hiair-307-existing-restore-resumed.png` |

The initial UI-test launch was blocked by the system XCTest automation passcode prompt; the owner completed it. That failed runner initialization is not an application failure.

## Remaining subscription boundary

The current HiAir account's server entitlement is free. Its prior verified monthly chain expired on 11 October; the Apple Sandbox screen's 23 August expiry is a different observation. Dates/plan labels do **not** identify the exact transaction responsible for the earlier ownership conflict. No ownership mapping or entitlement was changed, no purchase/renewal was initiated, and no active subscription is claimed. Restore has not yet completed on TestFlight 307. The app's local verification-history file was absent during this attempt: the stalled current-entitlement read did not reach receipt verification.

## Build 308 correction in progress

The restore path enumerated `Transaction.currentEntitlements` before explicit AppStore synchronization without a deadline. An unresponsive sequence trapped restoration in readingStore, even though the rest of the app remained usable.

The correction bounds each read at eight seconds. A first read timeout means unknown and moves to one explicit Apple synchronization; a post-sync timeout returns an App Store availability error, never a fabricated empty/successful entitlement. It uses the existing one-shot race so a non-cooperative child cannot keep its caller suspended. Canceled/late read completions cannot verify receipts; account/cancellation checks run before backend verification. Verified current restore transactions enter the existing bounded, owner-scoped diagnostic history. Settings now preserves the actionable API ownership-conflict message used by the paywall.

Targeted regression: **30 tests passed**, including hung first/post-sync reads, late response, cancellation before sync, existing verified receipts, empty/recheck and failed Apple sync. The first new timing test exposed a nondeterministic immediate test clock; replaced it with controlled gates and reran successfully. This is not device acceptance of 308. The full local iOS suite then passed **259 tests, zero failures/skips** (`/tmp/hiair-308-unit-final.xcresult`). Remote required checks, clean artifact, protected merge and TestFlight delivery are pending. Build 308 was unoccupied in ASC at the check.

Next: validate and deliver 308 through the normal release guard, install its TestFlight binary without deleting data, then repeat one restore and compare its exact StoreKit/backend result. Do not initiate another purchase to work around the failure. Android, large text/assistive technology and the wider offline/account-switch matrix were not newly verified here.
