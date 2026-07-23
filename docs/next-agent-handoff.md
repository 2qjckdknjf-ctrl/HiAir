# Next agent handoff — P0 Device Recovery

## Current state

- Branch: `fix/p0-device-recovery` (PR to `main`)
- Verdict: **CODE FIXED — WAITING FOR PHYSICAL RETEST**
- Production API still on `0243952` until PR merge + deploy
- TF 109 is pre-fix; need build >109 after merge

## What was fixed (code)

1. Startup single-flight + foreground refresh + diagnostics  
2. Location auth-grant auto-bootstrap + serialized fetches  
3. HealthKit/HC Connect no longer blocks on full sync; timeouts  
4. StoreKit finish-after-verify; unfinished restore; entitlement refresh on session change  

## Required next steps

1. Merge PR after CI green (no P0/P1 in review)  
2. If backend unchanged: skip API redeploy; confirm health SHA still `0243952` or newer  
3. Archive/upload TestFlight >109; assign «Первый»  
4. Run Phase 18 physical matrix on real iPhone  
5. Only then upgrade verdict to `IOS DEVICE RECOVERY VERIFIED`

## Do not

- Claim device PASS from simulator  
- Bypass Premium gates  
- Merge with failing CI  

## Docs

- `docs/audit/P0_DEVICE_RECOVERY_BASELINE.md`  
- `docs/audit/P0_DEVICE_RECOVERY_FINAL_REPORT.md`
