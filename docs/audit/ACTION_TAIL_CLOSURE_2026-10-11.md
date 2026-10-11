# ACTION tail closure — 2026-10-11

Scope: finish the current ACTION engineering slice from the 2026–2027 master specification, under the October security/release constraints. AMBIENT/ROUTES/CLIMATE TWIN/HOME, voice and provider/model research are separate releases.

## Implemented and verified locally

- Time preferences in both clients: any/morning/afternoon/evening, reference-location timezone, next-day rollover, DST-aware boundaries. Invalid/unknown timezone does not silently become the phone timezone.
- Real hourly intervals remain conservative. A missing hour cannot merge windows or satisfy an activity duration. Latest-start bounds do not remove subsequent forecast intervals needed to validate the activity. Invalid/naive/reversed API bounds fail validation.
- `recommendedWindow` is additive: actual planned duration, score/reasons/minimum coverage confidence from the whole verified candidate. Free responses expose only this one window; paid responses retain full alternatives/hourly contract. Entitlement-service failures remain failures; owned profiles/places still required.
- Canonical air hazard assessment reused for ACTION (including NO₂). No second set of pollution thresholds. Forecast pollen/smoke cannot be filled from current observations and remain outside the available hourly contract.
- Native calendar editor with explicit confirmation: EventKitUI on iOS, ACTION_INSERT on Android with scoped package visibility. No calendar ingestion or new server lifecycle table. iOS logs saved only after native completion; Android logs editor opening, not an invented save.
- Free action acceptance is per loaded plan locally; Premium reuses existing Protected Day recording. A plan with no recommended start cannot be marked planned.
- Late Action responses cannot overwrite newer parameters, tested with held/resumed requests in both clients.
- Five-language controls/reason labels. Raw internal reason identifiers are not shown to users. Missing dashboard AQI/PM2.5/humidity and hazard score use unavailable display instead of false zero.
- Historical roadmap/governance documents reconciled with protected main and the current registry. Pages deploy will publish source/run metadata and fail if production credentials are absent.

Local checks: backend gate PASS (491 tests, 76.50% coverage), iOS 234 unit tests PASS, Android 127 unit tests + lint PASS. Review/CI, immutable deployment and signed build 301 receipts must be recorded after execution; local tests are not delivery evidence.

## Independent quality evidence

Captured live Open-Meteo forecasts: Barcelona, Dubai, Los Angeles; 9 activity contexts, 6 comparable, no ranking-score regressions and no score improvements in this snapshot. Reproducible capture/replay script and result JSON are included. This verifies ranking non-regression, not forecast accuracy, health benefit or beta acceptance uplift. The real-world improvement criterion remains unmet pending beta observations; do not tune safety thresholds merely to manufacture a positive score.

## External / separate acceptance criteria

- Owner reports no physical Android available. Emulator tests do not close Health Connect/Play Billing physical certification.
- Full real-device consent/revoke/account-isolation/purchase/restore matrix requires isolated accounts and genuine sandbox receipts. Production verifier unit tests and approved IAP metadata do not substitute for transactions.
- Public store submission requires an explicit owner release instruction, per mobile/AGENTS.md; internal delivery is authorized.
- Public iOS 1.1 (245) is READY_FOR_SALE but historical source SHA is untraceable from available build metadata. Build 300/301 provenance is tracked; do not invent a historical SHA.

These are visible acceptance rows, not hidden coding TODOs. See registry, current QA report, ACTION_TAXONOMY and release receipts for the next executable steps.

Calendar references: Apple EventKitUI calendar-access documentation and Android Calendar Provider ACTION_INSERT. Full calendar read permissions are not requested on iOS 17+ or Android. iOS 16 uses the required legacy permission and purpose string without reading existing events.
