# Health Intelligence Coverage Audit

**Date:** 2026-07-21  
**Branch:** `feat/health-intelligence-100`  
**Scope:** maximize existing HealthKit / Health Connect → analytics → AI → Insights (no new major screens)

---

## Stage 1 — Apple Health (HealthKit)

| Metric | HK | App reads | UI | Analytics | AI | Recs / load | Gap / note |
|--------|:--:|:---------:|:--:|:---------:|:--:|:-----------:|------------|
| Steps | Y | Y | Y | trends | ctx | load→risk | — |
| Distance | Y | Y | Y | trends | ctx | — | expanded |
| Floors | Y | Y | Y | today | — | — | — |
| Active energy | Y | Y | Y | trends | ctx | — | expanded |
| Basal energy | Y | Y | Y | today | — | — | UI unhidden |
| Exercise minutes | Y | Y | Y | trends | ctx | load | expanded |
| Stand minutes | Y | Y | Y | today | — | — | not Apple Stand Hours category |
| Heart rate | Y | Y | Y | load | ctx | load | — |
| Resting HR | Y | Y | Y | trends+assoc | ctx | load | — |
| Walking HR | Y | Y | Y | today | — | — | — |
| HRV SDNN | Y | Y | Y | trends+assoc | ctx | load | — |
| HRV RMSSD | n/a iOS | Android | slot | trends | ctx | load | platform split |
| Respiratory rate | Y | tier3 | Y | today | ctx | — | connect tiers 1–3 |
| Blood oxygen | Y | tier3 | Y | today | ctx | — | connect tiers 1–3 |
| VO₂ Max | Y | Y | Y | today | — | — | — |
| Body temperature | Y | tier3 | Y | today | — | — | — |
| Wrist temperature | Y | tier3 | Y | today | — | — | Apple Watch |
| Sleep + stages | Y | Y | Y | trends+assoc | ctx | load | — |
| Workouts | Y | count/dur | Y | trends+assoc | ctx | load | no workout type taxonomy |
| Mindfulness | Y | Y | slot | — | — | — | collector added |
| Walking speed | Y | Y | Y | — | — | — | mobility sync |
| Step length | Y | Y | Y | — | — | — | mobility sync |
| Walking asymmetry | Y | Y | Y | — | — | — | mobility sync |
| Double support | Y | Y | Y | — | — | — | mobility sync |
| Cardio fitness (VO₂) | Y | via VO₂ | Y | today | — | — | — |
| ECG / AFib history | Y | N | N | N | N | N | out of wellness scope |
| Medications (HK) | Y | N | symptom bool | N | N | N | privacy / consent scope |
| Cycle tracking | Y | N | N | N | N | N | deferred (sensitive) |
| Mood / State of Mind | Y | N | N | N | N | N | deferred |
| Time in daylight | Y | N | N | N | N | N | deferred |
| Env / headphone audio | Y | N | N | N | N | N | deferred |
| Falls | Y | N | N | N | N | N | deferred / safety |

---

## Stage 2 — Health Connect (Android)

| Item | Fact |
|------|------|
| Record types read | steps, distance, active/total kcal, floors, HR, RHR, HRV RMSSD, VO₂, resp, SpO₂, body temp, exercise sessions, sleep (+stages) |
| Manifest `READ_*` | expanded to match synced types (was critically under-declared) |
| Added this sprint | `BodyTemperatureRecord` + `READ_BODY_TEMPERATURE` |
| Still not read | stand hours (no direct HC equivalent), mindfulness sessions, wrist temp, walking gait / mobility |
| Settings delete | now calls `/api/v1/health/data` + legacy wearable delete |
| OEM / device | requires Play Services Health Connect `SDK_AVAILABLE`; OEM gaps remain external |
| Unsupported | devices without HC store app; no silent fallback to fake metrics |

---

## Stage 3–5 — Analytics / AI / Personal insights

| Capability | Before | After |
|------------|--------|-------|
| Trend metrics | steps, RHR, HRV, sleep | + distance, energy, exercise, workouts, SpO₂, resp, deep sleep |
| Associations | PM2.5/cough, heat/fatigue, short sleep, sleep+AQI, RHR | + AQI/allergy, PM10, humidity/headache, ozone/breathing, sleep↔HRV, workout+env fatigue, steps↔milder symptoms |
| Env factors used | PM2.5, temp (partial) | + PM10, humidity, ozone, allergy_count |
| Personal load | steps + HR + RHR | + short sleep, HRV vs baseline, long exercise + AQI |
| AI explanation | air-only | health insight cards in `health_context` |
| Pollen | no E2E source | still deferred (no provider wired) |
| Seasonal trends | absent | approximated via 30d windows; true seasonality needs ≥90d history |

---

## Stage 6 — Symptoms

79-symptom taxonomy + journal UX closed in prior sprint. This branch does not change taxonomy count; Insights/associations consume symptom_type + severity.

---

## Stage 7–9 — Dashboard / Insights / Recommendations

- Dashboard triggers background HealthKit sync on reload (iOS).
- Insights: human section titles; period picker **7 / 30 days** (iOS + Android).
- Recommendation copy remains wellness-only (no diagnosis).
- Remaining polish: seasonal tab label, richer “yesterday vs today” deltas in AI (prompt expanded; needs live OpenAI deploy).

---

## Explicit deferred (honest)

1. ECG / AFib / medications / cycle / mood / daylight / audio / falls  
2. True pollen ingestion pipeline  
3. Android mobility + mindfulness collectors  
4. Physical-device HealthKit / HC E2E certification  
5. Production API deploy of this branch (Cloudflare token / Actions)
