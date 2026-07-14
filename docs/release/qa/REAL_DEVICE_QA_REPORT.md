# Real Device QA Report

Status: **GEOLOCATION RECOVERY** (2026-07-14) — engineering fixed; device E2E pending.

## Geolocation (2026-07-14)

| Item | Result | Notes |
|------|--------|-------|
| Root cause | **CONFIRMED** | iOS: permission only, no GPS read, Barcelona defaults; Android: no location stack, profile `0,0` |
| iOS LocationService | **IMPLEMENTED** | `requestLocation`, profile PATCH, dashboard reload |
| Android LocationController | **IMPLEMENTED** | runtime permissions, FusedLocation, no `0,0` bootstrap |
| Backend `(0,0)` policy | **IMPLEMENTED** | reject on create/patch |
| iOS unit tests | **PASS** | GeoCoordinatesTests 5/5 |
| Android unit tests | **PASS** | GeoCoordinatesTest |
| Backend tests | **PASS** | test_profile_coordinates 6/6 |
| TestFlight build 15 | **PENDING UPLOAD** | CFBundleVersion 15; build 73 lacks fix |
| Physical iPhone E2E | **NOT RUN** | owner session required |

## Subscription certification (2026-07-14)

| Item | Result | Notes |
|------|--------|-------|
| Privacy export ≠ Premium | **PASS** | prod: 401 unauth; auth never 402 |
| Backend subscription tests | **PASS** | incl. privacy + planner regression |
| Production smoke | **PASS** | `subscription_production_smoke.py` on current prod (`ea66272`) |
| Backend deploy `86354b4` | **BLOCKED** | run `29073242041` — token preflight 401 |
| Production `deploy_git_sha` | **ABSENT** | old image; subscription backend fixes not live |
| TestFlight ASC build 73 | **VALID** | CFBundleVersion 14; IAP products READY_TO_SUBMIT |
| iOS sandbox purchase E2E | **BLOCKED** | owner + physical iPhone; after green deploy |
| Android Play Billing E2E | **EXTERNALLY BLOCKED** | no Play app |

## Master RC sprint — code certification (2026-07-07)

| Item | Result | Notes |
|------|--------|-------|
| Production fake UI (Barcelona/Alex/actions) | **FIXED** | iOS dashboard + l10n; Android secondary screens |
| iOS `HiAirTests` Info.plist | **FIXED** | `GENERATE_INFOPLIST_FILE: YES` in `project.yml` |
| Android assembleDebug/Release + lint + tests | **PASS** | arm64 JDK 17 required |
| iOS build + tests | **PASS** | 4/4 tests |
| Backend pytest | **PASS** | 119 tests |
| Production API | **PASS** | `source=sample` 200; health warm ~0.28s |
| Android physical device QA | **BLOCKED** | no `adb`/device; use **release** APK for `api.hiair.io` |
| iOS physical device QA | **BLOCKED** | iPhone offline; use **Release** for `api.hiair.io` |

## Install matrix (owner session required)

| Platform | Device | Build | API target | Status |
|----------|--------|-------|------------|--------|
| Android | TBD | `app-release-unsigned.apk` | `https://api.hiair.io` | BLOCKED |
| iOS | iPhone (offline) | Release / TestFlight | `https://api.hiair.io` | BLOCKED |
| iPad | TBD | — | — | NOT STARTED |

Artifacts:

- `mobile/android/app/build/outputs/apk/release/app-release-unsigned.apk`
- iOS: archive via Xcode Release scheme

## Critical flows (all BLOCKED until hardware session)

install → login → onboarding → dashboard live → planner → symptoms → privacy export/delete → logout/re-login → offline/retry
