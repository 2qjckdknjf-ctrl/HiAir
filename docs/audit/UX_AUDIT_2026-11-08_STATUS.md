# UX audit 2026-11-08 — status ledger

Baseline audit: `design-audit-hiair-2026-11-08/HIAIR_DESIGN_UX_AUDIT_RU.md` against `/Users/alex/Projects/HIAir-main` @ `3ac1596e`.
Working branch: `fix/ux-audit-2026-11-08` from remote main `460d61c3`.
Dirty WIP in `/Users/alex/Projects/HIAir` left untouched.
Prior reviewed HEAD `683bdc84` is **not** the release candidate after R1–R10 fixes.

| ID | Status | Evidence |
|---|---|---|
| UX-01 Health required on onboarding | **Implemented** | Skip CTA; primary label matches action when Health unavailable; Skip stays during consentSaving |
| UX-02 Premium before server confirm | **Implemented (code)** | Dismiss blocked only while `isSystemPurchaseSheetActive`; pending/verify do not trap Close; owner guard on purchase completion |
| UX-03 Restore states | **Implemented (code)** | Final copy from latest response; already_active not frozen from pre-request flag |
| UX-04 Insights partial catastrophe | **Implemented (code)** | Soft partial banner; failed-source retry; 402 does not auto-open paywall while activation pending |
| UX-05 Dashboard hierarchy | **Partial** | Freshness pill honesty; compact action reorder still open |
| UX-06 Live freshness | **Implemented (code)** | Pill uses Live/Cached/stale/no-data from `freshness` |
| UX-07 Revoke retry → connect | **Implemented** | `retryPendingRemoteCleanup` repeats delete vs revoke by durable kind+owner; uploads blocked until resolved |
| UX-08 Android fake chart | **Implemented** | Empty → no chart; trailing-gap fill flushed per segment |
| UX-09 iOS chart timestamps | **Implemented (unit)** | Shared `HiAirChartTimeScale` timestamp→X for line/labels/window/marker; overnight window coordinate test |
| UX-10 Dynamic Type / contrast | **Implemented (code)** | Semantic fonts; navy CTA; Reduce Motion skeleton — runtime VoiceOver/TalkBack not re-run here |
| UX-11 Misleading CTAs | **Implemented** | location_later; single step indicator; planner.go_home |
| UX-12 Settings / symptoms density | **Partial** | Premium CTAs + delete confirm; full Settings regroup / Symptoms reorder open |
| UX-13 Auth field labels | **Implemented (code)** | Persistent labels; `auth.password_rules` shown; ES/IT/FR labels no longer embed rules |

## R1–R10 closure (source)

| ID | Verdict | Before → After |
|---|---|---|
| R1 | Fixed (unit) | revokeFailed retry called revoke → `retryPendingRemoteCleanup` + durable kind/owner |
| R2 | Fixed (code) | Close tied to purchaseBusy/verify → only `isSystemPurchaseSheetActive` |
| R3 | Fixed (unit) | hour/24 highlight → absolute ISO timestamp scale + coordinate test |
| R4 | Fixed (code) | purchase completion lacked owner check → guard `session.userId`/`status.userId` |
| R5 | Fixed (code) | restore used pre-request `alreadyActive` → final entitlement response |
| R6 | Fixed (unit) | full 4-source refresh on retry → `failedSources` selective retry |
| R7 | Fixed (code) | 402 auto `showPaywall` on pending → `presentPaywallIfNeeded` |
| R8 | Fixed (code) | Connect label + silent skip → Skip label when unavailable; Skip during save |
| R9 | Fixed (code) | rules unused / ES-IT-FR on label → caption + clean labels |
| R10 | Fixed (code) | Android trailing gap no fill → flush fill on each closed segment |

## Verification

- Unit helpers added/updated: chart coordinates, health delete retry/owner, insights selective retry
- Screenshot matrix: success + partial insights assertions added (not yet re-run this pass)
- Physical Sandbox purchase / TestFlight install / Android device: **NOT RUN**
- Merge / upload: **blocked until** CI green on post-fix SHA and release guard

## Remaining for release

1. Commit + push; wait required CI/review on new HEAD
2. Build bump after ASC check; rebuild IPA from clean final SHA (do not reuse 683bdc84 IPA)
3. UX-05 / UX-12 remain Partial unless separately closed
4. TestFlight only after merge ancestry + guard; device QA for Health skip / purchase pending / revoke
