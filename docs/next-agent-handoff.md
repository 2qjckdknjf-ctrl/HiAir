# Next agent handoff — P0 Runtime UX Recovery

## Current state

- **main** @ `cda6722` (PR #34 merged)
- Canonical iOS build number: **127**
- TestFlight **127** VALID → «Первый» (`IN_BETA_TESTING`)
- Production API: `deploy_git_sha=0243952` (backend unchanged by PR #34; no redeploy)
- Verdict: **CODE FIXED — WAITING FOR PHYSICAL RETEST**

## What was fixed (code)

1. City: account-scoped reverse geocode + latest-wins + logout isolation  
2. Health: durable consent gate; cancellable `startBackgroundHealthSync` coordinator; revoke/delete clears local consent **before** remote await  
3. Premium: Activating optimistic unlock; account-attributed rollback; logout clears pending  
4. CI flake: serialized health/place races; isolated PlaceGeocoding actor in unit tests  

## Required next steps

1. Physical iPhone matrix on **TF 127** (city / Health / revoke during sync / Premium / RuntimePerformanceProbe)  
2. Only then upgrade verdict to device-verified  
3. Android device still pending; Play Billing still externally blocked  

## Do not

- Claim device PASS from simulator  
- Bypass Premium or Health consent gates  
- Publish App Store production  

## Docs

- `docs/audit/P0_RUNTIME_UX_RECOVERY.md`  
- `docs/audit/P0_DEVICE_RECOVERY_FINAL_REPORT.md`  
- `docs/release/qa/REAL_DEVICE_QA_REPORT.md`
