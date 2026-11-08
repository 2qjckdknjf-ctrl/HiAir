# UX audit 2026-11-08 — status ledger

Baseline audit: `design-audit-hiair-2026-11-08/HIAIR_DESIGN_UX_AUDIT_RU.md` against `/Users/alex/Projects/HIAir-main` @ `3ac1596e`.
Working branch: `fix/ux-audit-2026-11-08` from remote main `460d61c3` (docs-only delta vs audit SHA).
Dirty WIP in `/Users/alex/Projects/HIAir` (`design/redesign-v4-deep-glass`) left untouched.

| ID | Status | Evidence |
|---|---|---|
| UX-01 Health required on onboarding | **Implemented** | Skip CTA + advance when Health unavailable / consent fail path; connect later via Settings |
| UX-02 Premium before server confirm | **Implemented (code)** | Paywall dismisses only on confirmed Premium; pending copy forbids repurchase; Settings check-access CTA |
| UX-03 Restore states | **Implemented (code)** | restore_success / already_active / nothing / verify_pending distinguished |
| UX-04 Insights partial catastrophe | **Implemented (code)** | Soft partial banner; success mock includes `/api/insights/adaptation`; matrix `insights_partial` |
| UX-05 Dashboard hierarchy | **Partial** | Freshness pill honesty; compact action reorder still open |
| UX-06 Live freshness | **Implemented (code)** | Pill uses Live/Cached/stale/no-data from `freshness`, not “any environmental” |
| UX-07 Revoke retry → connect | **Implemented** | `onRetryRevoke` retries revoke; delete Health confirms scope HiAir vs Apple Health |
| UX-08 Android fake chart | **Implemented** | Empty → no chart; title risk forecast; Pollen toggle removed; unknown = gap |
| UX-09 iOS chart timestamps | **Implemented (unit)** | Place TZ hour parsing; unknown ≠ low; axis from point hours — mid-day/DST runtime still open |
| UX-10 Dynamic Type / contrast | **Implemented (code)** | Semantic system fonts; navy CTA label; Reduce Motion static skeleton |
| UX-11 Misleading CTAs | **Implemented** | location_later; single step indicator; planner.go_home |
| UX-12 Settings / symptoms density | **Partial** | Premium state CTAs; delete confirm; full Settings regroup / Symptoms reorder open |
| UX-13 Auth field labels | **Implemented (code)** | Persistent labels + placeholders; password rules not on login label |

## Verification so far

- Aikido scan on touched files: clean
- Unit: `HourlyRiskChartHonestyTests` + `SessionLogoutIsolationTests` PASS on iPhone 17 Pro sim OS 26.5
- Physical Sandbox purchase / TestFlight install / Android device: **NOT RUN**
- Screenshot capture with new fixtures: **NOT RUN** this session

## Remaining for release

1. Broader HiAirTests suite + StoreScreenshotTests (success + insights_partial)
2. Build number bump (303 → next ASC max) + TestFlight upload
3. UX-05 / UX-12 remaining hierarchy polish
4. Honest runtime verification of purchase pending / Health skip on device
