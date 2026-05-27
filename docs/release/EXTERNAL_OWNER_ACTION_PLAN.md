# External Owner Action Plan

- Source env file: `/Users/alex/Projects/HIAir/backend/.env.local`

## Current strict status
- All external items are ready.


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
