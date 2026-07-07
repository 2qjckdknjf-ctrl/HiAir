# Real Device QA Report

Status: **RC-2 BLOCKED** (2026-07-07) — code blockers closed; owner hardware session pending.

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
