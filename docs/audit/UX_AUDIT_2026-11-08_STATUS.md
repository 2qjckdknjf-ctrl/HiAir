# UX audit 2026-11-08 — status ledger

Baseline audit against `/Users/alex/Projects/HIAir-main` @ `3ac1596e`.
PR96 merged: https://github.com/2qjckdknjf-ctrl/HiAir/pull/96  
Feature HEAD: `688477f1` · Merge commit (main): `63923aa1` · trees equal.

| ID | Implemented | Verified | Released |
|---|---|---|---|
| UX-01 Health skip onboarding | Yes | Unit/code | In TF build 304 |
| UX-02 Premium pending / dismiss | Yes | Code | In TF build 304 |
| UX-03 Restore states | Yes | Code | In TF build 304 |
| UX-04 Insights partial | Yes | Unit + matrix tests added | In TF build 304 |
| UX-05 Dashboard hierarchy | Partial | — | Partial in TF |
| UX-06 Live freshness | Yes | Code | In TF build 304 |
| UX-07 Health delete retry | Yes | Unit | In TF build 304 |
| UX-08 Android chart honesty | Yes | Code | Source on main (Android device not run) |
| UX-09 iOS chart timestamps | Yes | Unit coords | In TF build 304 |
| UX-10 Dynamic Type / contrast | Yes (code) | Runtime VoiceOver/TalkBack not re-run | In TF build 304 |
| UX-11 Misleading CTAs | Yes | Code | In TF build 304 |
| UX-12 Settings / symptoms density | Partial | — | Partial in TF |
| UX-13 Auth labels / rules | Yes | Code | In TF build 304 |

## R1–R10

| ID | Implemented | Verified | Released |
|---|---|---|---|
| R1 delete retry | Yes | Unit | TF 304 |
| R2 paywall dismiss stages | Yes | Code | TF 304 |
| R3 chart timestamp scale | Yes | Unit | TF 304 |
| R4 purchase account switch | Yes | Code | TF 304 |
| R5 restore alreadyActive | Yes | Code | TF 304 |
| R6 insights failed-set retry | Yes | Unit | TF 304 |
| R7 pending vs auto-paywall | Yes | Code | TF 304 |
| R8 onboarding Connect/Skip honesty | Yes | Code | TF 304 |
| R9 password_rules l10n | Yes | Code | TF 304 |
| R10 Android trailing fill | Yes | Code | Source on main |

## Delivery evidence

| Item | Value |
|---|---|
| Source / PR | `688477f1` / #96 MERGED |
| Merge SHA | `63923aa1` on `origin/main` |
| CI on feature HEAD | android-build, ios-build, backend-smoke, Security Reviewer SUCCESS |
| IPA path | `mobile/ios/build/releases/63923aa17bf9-kYbUjs/export/HiAir.ipa` |
| IPA SHA256 | `f67e8513f9b064ee85e05f28e7911ce746af8f0726c76abb042c77991491d668` |
| Manifest | clean_source=true, ios_source_sha=`63923aa1` |
| Bundle | `com.hiair.app` 1.2 (304) |
| Upload | submitted UUID `da39f9b4-e175-43de-b873-77b85ef730d7` |
| ASC | processing → **VALID** |
| TestFlight group | assigned to internal **«Первый»** |
| Device install | **NOT confirmed** this session |
| Sandbox purchase / Health delete on device | **NOT RUN** |
| Android physical | **NOT RUN** |
| Local api.hiair.io | timed out from this Mac; gate used fresh GHA readback `42513020960` (API SHA `3ac1596e`, backend tree match) |

## Remaining limitations

- UX-05 / UX-12 remain Partial.
- On-device: Health skip, purchase pending/activation, restore, revoke/cleanup, large text/VoiceOver still need the phone.
- Old IPA from `683bdc84` is obsolete; do not redistribute it.
