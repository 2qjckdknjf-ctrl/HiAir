# Current device certification — build 301

Status: **PARTIAL — full physical/store matrix not certified**.

Candidate source `995b10e9e35026c42a11cafa70e81766ed0dbd1d`, merged in PR86 as `48ed1a0964507bb795183041f60d5f5035b1d303`. iOS 1.2 (301), Android 1.2.0 (301). Production API/web: `48ed1a09`. TestFlight VALID / IN_BETA_TESTING; Play Internal upload/edit commit SUCCESS. See RELEASE_MANIFEST_301_2026-10-11.json.

| Scenario | Evidence/result |
|---|---|
| Backend regression | 493 tests, gate PASS; current branch CI PASS |
| iOS regression | 235 unit tests PASS; current branch CI PASS |
| Android regression | 128 unit tests and lint PASS; current branch CI PASS |
| iOS packaging | Signed archive/export, HealthKit entitlement/purpose strings, privacy manifest, build 301 PASS |
| iPhone existing-session / live ACTION / calendar cancel | PASS: Release / Apple Development candidate, one executed UI test, zero skipped/failed; `.evidence/action-physical-301-live.xcresult` |
| Genuine sandbox purchase + restore | Owner confirms Sandbox configured; transaction not yet certified |
| Physical Android / Health Connect / Play Billing | Device unavailable, as confirmed by owner |
| Full consent/revoke/delete/account-switch/offline/language matrix | Not completed on current physical candidate; use isolated accounts |

Private logs/screenshots stay in `.evidence/`; never put owner health values, coordinates, identifiers, receipts or credentials in this report. The physical runner rejects stale binaries and skipped checks.

Previous checkpoints are preserved in [historical QA](archive/REAL_DEVICE_QA_HISTORY_THROUGH_2026-10-11.md). Historical blocked/failed builds are not the status of build 301. App Store 1.1 (245) remains the public build; internal delivery is a separate state.
