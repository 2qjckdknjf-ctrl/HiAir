# External Owner Action Plan

- Source env file: `/Users/alex/Projects/HIAir/backend/.env.local`

## Current strict status
- `MISSING=0`
- `BLOCKED=1`

## Unresolved items
| Name | Status | Detail |
|---|---|---|
| `REAL_DEVICE_QA_EXECUTION` | `BLOCKED` | Current real-device certification is not complete (Status: BLOCKED; 0 PASS, 40 unresolved rows) |

## Required runtime env values
- No missing env values detected.

## Mandatory legal finalization
- Legal status markers are already finalized.

## Real-device certification
- Connect physical iOS and Android devices and install the named signed candidates.
- Execute every current matrix row in `docs/release/qa/REAL_DEVICE_QA_REPORT.md`.
- Set `Status: PASS` only after every current row is `PASS` with safe evidence.

## Verification commands
- `python3 scripts/release/check_external_readiness.py --env-file backend/.env.local`
- `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`
- `scripts/release/hiair_final_gate.sh --strict-external`

## Safety rules
- Do not commit `.env.local`.
- Do not commit APNS key files.
- Do not commit FCM service-account JSON.
- Do not commit review/test passwords.
