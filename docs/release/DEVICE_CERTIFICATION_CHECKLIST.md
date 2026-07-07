# Device Certification Checklist (Owner)

Use **release** builds only (`https://api.hiair.io`).  
Record results in `docs/release/qa/REAL_DEVICE_QA_REPORT.md`.

## Android (release AAB/APK)

| # | Scenario | Pass | Notes |
|---|----------|------|-------|
| 1 | Install release build | ☐ | Signed AAB via Play Internal or `adb install` release APK |
| 2 | Login (email) | ☐ | |
| 3 | Onboarding / profile bootstrap | ☐ | Auto profile via `/api/profiles` |
| 4 | Dashboard — live data | ☐ | Source label Live/Cached/Sample |
| 5 | Planner | ☐ | |
| 6 | Symptoms log | ☐ | |
| 7 | Insights / patterns | ☐ | |
| 8 | Privacy export | ☐ | Settings → export JSON |
| 9 | Privacy delete (confirm cancel first) | ☐ | |
| 10 | Logout → login again | ☐ | Session restore |
| 11 | Offline → retry | ☐ | Airplane mode, tap Retry |
| 12 | Push permission (Android 13+) | ☐ | POST_NOTIFICATIONS prompt |
| 13 | Health Connect connect/deny | ☐ | App works when denied |
| 14 | IAP sandbox (optional) | ☐ | Architecture ready; verify purchase |

## iPhone (TestFlight Release)

| # | Scenario | Pass | Notes |
|---|----------|------|-------|
| 1 | Install from TestFlight | ☐ | Build 13+ |
| 2 | Login (email) | ☐ | |
| 3 | Sign in with Apple | ☐ | |
| 4 | Onboarding / profile | ☐ | |
| 5 | Dashboard — live data | ☐ | |
| 6 | Planner | ☐ | |
| 7 | Symptoms | ☐ | |
| 8 | Morning briefing settings | ☐ | |
| 9 | Privacy export | ☐ | |
| 10 | Privacy delete | ☐ | |
| 11 | Logout → login | ☐ | |
| 12 | Offline → retry | ☐ | |
| 13 | Push notifications | ☐ | Permission + token registration |
| 14 | HealthKit connect/deny | ☐ | Real `requestAuthorization` |
| 15 | IAP sandbox (optional) | ☐ | StoreKit sandbox |

## Sign-off

- **Tester name:** _______________
- **Device models / OS:** _______________
- **Build numbers:** iOS ___ / Android versionCode ___
- **Open issues:** _______________

When all critical rows are PASS, run:

```bash
python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local
```
