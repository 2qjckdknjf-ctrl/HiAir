# Current device certification — build 302

Status: **PARTIAL — 302 primary Insights verified; full physical/store matrix remains partial**.

Signed iOS source `97bf114c9ff950f8774063097fa40b5f03e1cdf0`, PR88 merge/API `e826a9e482f72d78a746ab5a96dc72bc8df6d5cb`. iOS 1.2 (302): TestFlight VALID / IN_BETA_TESTING. Android 1.2.0 (302): Play Internal upload/edit commit SUCCESS. Website remains `48ed1a09`. See RELEASE_MANIFEST_302_2026-10-11.json.

| Scenario | Evidence/result |
|---|---|
| Backend regression | 498 tests / 76.52% coverage, protected CI 38142180313 PASS |
| iOS regression | 241 unit, protected CI 38142180329 PASS |
| Android regression | Required CI 38142180317 PASS; 128 unit/lint baseline |
| iOS packaging | Clean signed archive/export/hash; TestFlight 302 VALID / IN_BETA_TESTING |
| Physical installed candidate | Device readback 1.2 (302); explicit install preserves owner data |
| iPhone existing-session / live ACTION / calendar cancel | Previous 301 PASS, one UI test/zero skipped; `.evidence/action-physical-301-live.xcresult` |
| Monthly Sandbox purchase | 301: owner confirmed; StoreKit verified → backend HTTP 200 / active entitlement |
| Genuine Sandbox restore | Started on 301; completion unverified, owner asked to repeat on 302 |
| Primary paid Insights cellular latency | 302 post-activation PASS 5.44s; one executed/zero skipped/failed, `.evidence/perf-302-post-restore-insights.xcresult`. Earlier Premium-locked attempt preserved as failed, not counted as paid loading |
| Invalid initial purported 302 test | Actually launched installed 301; excluded from 302 certification. Runner now installs proven candidate and reads installed version before testing |
| Physical Android / Health Connect / Play Billing | Device unavailable, owner confirmed |
| Full consent/revoke/delete/account-switch/offline/language matrix | Not completed on current physical candidate; use isolated accounts |

Private logs/screenshots remain in `.evidence/`; no owner health values, coordinates, identifiers, receipts or credentials belong in this report. The runner verifies source tree, installed version, actual deployed app fingerprint and test counts. A dismissed spinner or paywall response does not certify successful paid data loading.

Previous 300/301 checkpoints are preserved in manifests and [historical QA](archive/REAL_DEVICE_QA_HISTORY_THROUGH_2026-10-11.md). Public App Store 1.1 (245) and internal delivery are separate states.
