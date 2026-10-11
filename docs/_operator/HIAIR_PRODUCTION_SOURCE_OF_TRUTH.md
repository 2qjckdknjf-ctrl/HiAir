# HiAir source of truth — current checkpoint, 2026-10-11

Canonical source is protected main (d6fd513d baseline). PR83 reconciled the former feature stack; PR84/85 reconciled delivery configuration and historical documents. The ACTION closure branch is based on this main, with build 301 in validation. Do not start from the former upgrade branch.

| Surface | Current delivered version/source | Evidence |
|---|---|---|
| Backend production | 833a06e48e3e2faf1c51719e3a3b5f59761736bd | /api/health, deployment 38130417768, live-AI/feature smokes |
| iOS public | 1.1 (245), historical SHA UNKNOWN | App Store Connect READY_FOR_SALE, build 97bb126d-f7ba-4dec-9899-e19f277a6307 |
| iOS internal | 1.2 (300), source 3c15a9c5 | VALID / IN_BETA_TESTING, release manifest |
| Android internal | 1.2.0 (300), source 828b3eb3 | Google Play edit commit, run 38130939253 |
| Android public | Not established; do not flip PR80 links | Public-listing HTTP check required independently |
| Web | hiair.io live; previous artifact SHA UNKNOWN | Pages pipeline will publish /release.json for future source/run traceability |
| Supabase | Deletion-operation/work-site tables RLS true | Metadata-only readback, project qhxesaemlhzwbunpqjoo |

| Capability | Classification | Remaining evidence |
|---|---|---|
| Current risk / real Forecast Truth | PRODUCTION backend | Physical mobile matrix separate |
| Best Time / Action | PARTIAL | Current closure code/CI/build/deploy/device receipts |
| Pollen/smoke/UV/dust/NO₂ | PRODUCTION current hazards | Hourly pollen/smoke unavailable; not inferred |
| Smart Alerts / Saved Places / Family / Travel / Work Safety | PRODUCTION backend, PARTIAL certification | Signed current-device scenarios |
| HealthKit / Health Connect / Personal Load / Health Intelligence | PARTIAL certification | Genuine device permissions/data/revoke/account isolation |
| Symptoms / Patterns / Morning Briefing | Existing implementation | Current device acceptance rows |
| Premium | PARTIAL store certification | Approved Apple products + fail-closed code; genuine sandbox purchase/restore still required |
| Privacy export/delete | PRODUCTION API + synthetic lifecycle verification | Current physical account flows separate |
| Widgets / Live Activities / Apple Watch / Wear OS / routes / indoor/home | ROADMAP | No native targets/domain implementations found in current tree; not part of ACTION closure |
| Analytics/experiments | Diagnostic event logging | See ACTION_TAXONOMY; no fabricated business KPI evidence |

Truth hierarchy remains runtime → deployed code → candidate → tests → technical docs → old plans/marketing. Record source, merged, deployed SHA and artifact separately. Current 301 receipts supersede 300 only after execution; public release and complete device certification are distinct statuses.
