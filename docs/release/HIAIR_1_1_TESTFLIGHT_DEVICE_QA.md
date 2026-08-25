# HiAir 1.1 — TestFlight / Physical Device QA

**Marketing version:** `1.1`  
**Build:** `182`  
**Branch tip:** `feat/hiair-1.2-best-time-planner`  
**API:** `https://api.hiair.io`

## Build
- [ ] iOS archive uploaded to TestFlight (`MARKETING_VERSION=1.1`, `CURRENT_PROJECT_VERSION=182`)
- [ ] Android internal track optional (`versionName=1.1.0`, `versionCode=182`)

## Device checks (physical)
- [ ] Fresh install login (email + Sign in with Apple)
- [ ] Dashboard live risk + hazards (pollen/smoke show unavailable outside coverage — never fake zeros)
- [ ] Travel mode: start on saved place → dashboard/planner/alerts follow travel coords + local quiet hours
- [ ] Work site risk: meteo WBGT shows estimated disclaimer; instrument reading (if ingested) drops disclaimer
- [ ] Adaptation insights show association-not-causation copy
- [ ] Premium gate intact (planner activity-plan 402 when free)
- [ ] HealthKit connect still works; revoke is local-first
- [ ] No crash on offline / denied location

## Honest status rule
Do **not** mark READY FOR FIRST 10 USERS until the physical checklist above is completed on a real device.
