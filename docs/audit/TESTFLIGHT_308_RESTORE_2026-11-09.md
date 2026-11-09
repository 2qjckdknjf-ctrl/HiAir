# TestFlight 308 restore correction — 9 November 2026

## Delivery

Clean source `aacd89e6abc56c17041aa792ff6cb57c8240e5d8`; [PR102](https://github.com/2qjckdknjf-ctrl/HiAir/pull/102) merged as `aafa6b45762a7d66916d0b7ee1803c9a04d87933` at 21:51:10 UTC. The source, CI and merge iOS trees match. Exported 1.2 (308) passed strict codesign and HealthKit packaging checks. IPA SHA256: `ec1d2057850940c1f240f24e37a93c74c5a6f61fa2470bcc8c52d2c3c919e829`.

Upload succeeded at 21:53:06 UTC; ASC build `58b5a6fd-1c7f-4424-a713-25f2affb3c19` is **VALID / IN_BETA_TESTING** and present in internal group “вт” (complete membership response, no next page). No public App Store submission. [Machine-readable receipt](../release/RELEASE_MANIFEST_308_2026-11-09.json).

The fresh release guard confirmed source ancestry in origin/main, artifact hash, matching mobile tree and the live backend source fingerprint. Backend tree is unchanged, so no backend deployment was performed. Supabase remained ACTIVE_HEALTHY; no user records or subscription ownership mappings were altered.

## Before, after and evidence

| Case | Before on 307 | Implemented in 308 | Verified | Released |
| --- | --- | --- | --- | --- |
| Stalled current-entitlement read | Actual TestFlight restore stayed readingStore beyond 120s | Each snapshot has an 8s deadline; unknown empty result is not success | Controlled timeout, late-response and cancellation regressions; device repeat pending | Internal TestFlight |
| Transaction emitted before a stall | Initial candidate discarded emitted JWS on timeout | Retain yielded verified JWS for backend verification | Pre/post-sync yielded-then-hung regression tests; renewed review | Internal TestFlight |
| Account change while awaiting read | Initial candidate could prompt Apple sign-in for the old session | Check current owner before explicit Apple sync and backend work | Delayed read A→B: zero sync calls; device account-switch matrix pending | Internal TestFlight |
| Ownership error in Settings | Generic restore error concealed actionable conflict | Same localized ownership message as paywall | Five-language mapping regression; actual conflicting transaction still unidentified | Internal TestFlight |

Local full suite: **262 passed, zero failed/skipped**, iPhone 17 Pro simulator / iOS 26.5 (23F77). Remote [iOS run 42702685380, attempt 2](https://github.com/2qjckdknjf-ctrl/HiAir/actions/runs/42702685380) certified **262 passed, zero failed/skipped** on the exact source. Attempt 1 failed before tests during the system simulator's data migration, exceeding the 300s boot deadline; the unchanged second attempt passed. Required Android/backend checks passed with those domains unchanged. Security review and renewed Bugbot review passed; both original review threads were resolved by the renewed review. This is code validation, not proof of paid access.

Private local evidence is preserved under `mobile/ios/build/device-qa/restore-308-2026-11-09/`: unit xcresult, signing result, failed boot diagnostics, final CI log, merge, upload, release guard and ASC/group readbacks. The generated IPA sidecar was not rewritten; the initial candidate archive is retained separately and was not uploaded.

## Device acceptance remains separate

**308 has not yet been verified installed or tested on the physical iPhone.** The owner has been asked to update through TestFlight, keeping application data. Then verify the distribution signature/build, dashboard, Health and one explicit restore without buying/renewing/changing plans.

At 21:59:15 UTC the previously connected iPhone was not found by installation-proxy discovery. No replacement development build was installed. The required owner step is the TestFlight update and reconnection/unlock; elapsed waiting is not installation evidence.

Actual TestFlight **307** evidence remains [separate](TESTFLIGHT_307_DEVICE_2026-11-09.md): dashboard risk visible after 8.362581s (one sample), Health consent and aggregate upload confirmed on the server, monthly 5.99 EUR and yearly 44.99 EUR catalog prices visible. Restore failed; Apple Sandbox management displayed a canceled/expired subscription ending 23 August (year not shown). The current account's server entitlement is free. None of these facts proves which transaction caused the prior ownership conflict.

No new purchase or ownership transfer was performed. Active restoration, monthly/yearly purchase activation, exact prior conflicting transaction, physical Android and the wider UX audit remain open. Do not label this delivery as full subscription or UX-audit acceptance.
