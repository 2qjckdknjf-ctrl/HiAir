# External Owner Action Plan

- Source env file: `/Users/alex/Projects/HIAir/backend/.env.local`

## Current strict status
- `MISSING=1`
- `BLOCKED=1`

## Unresolved items
| Name | Status | Detail |
|---|---|---|
| `REAL_DEVICE_QA_REPORT_REQUIRED_CONTENT` | `MISSING` | Missing required content markers: iOS device matrix, Android device matrix, App version, Build number, Open issues, install/open app, session restore, dashboard load, planner load, symptom log create, insights load, morning briefing settings, notification permission, push token registration, account delete, offline/poor network, RU localization, EN localization |
| `REAL_DEVICE_QA_EXECUTION` | `BLOCKED` | Real device QA not executed (2 BLOCKED rows, 0 PASS) |

## Required runtime env values
- No missing env values detected.

## Mandatory legal finalization
- Legal status markers are already finalized.

## Verification commands
- `python3 scripts/release/check_external_readiness.py --env-file backend/.env.local`
- `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`
- `scripts/release/hiair_final_gate.sh --strict-external`

## Safety rules
- Do not commit `.env.local`.
- Do not commit APNS key files.
- Do not commit FCM service-account JSON.
- Do not commit review/test passwords.
