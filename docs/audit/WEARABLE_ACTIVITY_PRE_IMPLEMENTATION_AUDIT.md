# Wearable & Activity Intelligence v1 — Pre-Implementation Audit

**Date:** 2026-06-04  
**Branch:** `feature/wearable-activity-insights-v1`  
**Status:** Pre-implementation baseline

## Executive Summary

HiAir is a production-ready wellness app (iOS SwiftUI + Android View-based Kotlin, FastAPI backend, Supabase PostgreSQL). **No HealthKit or Health Connect integration exists today.** Environmental risk via `air_risk_engine.py` is the canonical path; legacy numeric `risk_engine.py` is deprecated. A `wearable_insights_enabled` entitlement flag exists in schema but has no gate logic. This audit defines the integration surface for v1 without breaking auth, subscriptions, or the primary risk pipeline.

## 1. Project Structure

| Layer | Technology | Key paths |
|-------|------------|-----------|
| iOS | SwiftUI | `mobile/ios/HiAir/` |
| Android | Kotlin (View, not Compose) | `mobile/android/app/src/main/java/com/hiair/` |
| Backend | FastAPI + psycopg | `backend/app/` |
| Database | Supabase PostgreSQL | `backend/sql/` (latest: **013**) |
| Web | Static Cloudflare Pages | `web/` |
| API production | `https://api.hiair.io` | Cloudflare Containers |

## 2. What Already Exists

### Risk & environment
- **Primary engine:** `backend/app/services/air_risk_engine.py` — heat + air discrete levels, safe windows, reason codes.
- **Legacy engine:** `backend/app/services/risk_engine.py` — 0–100 numeric score (deprecated `/api/risk/*`).
- **Mobile path:** `/api/air/current-risk` via `APIClient.fetchCurrentRisk` (iOS) / `ApiClient.fetchCurrentRisk` (Android).
- **Thresholds doc:** `docs/risk-thresholds-v1.md`.

### User data & privacy
- Symptom logs with optional `sleep_quality` (manual, not wearable).
- Privacy export/delete: `GET /api/privacy/export`, `POST /api/privacy/delete-account`.
- RLS patterns in `003_supabase_auth_rls.sql` (direct `user_id`) and `010_public_tables_rls_lockdown.sql` (profile join).
- GDPR docs: `docs/privacy-policy-draft.md`, `docs/06_PRIVACY_LEGAL_STATUS.md`.

### Mobile UX
- **iOS onboarding:** 6 steps including location + notifications (`OnboardingView.swift`); no health step.
- **Android:** No onboarding UI; goes to dashboard after auth.
- **Dashboard:** `DashboardView.swift` / `DashboardScreenRenderer.kt`.
- **Settings:** Privacy export/delete, language, alerts (`SettingsView.swift` / `SettingsScreenRenderer.kt`).
- **i18n:** Inline maps in `AppSession.swift` (iOS) and `AndroidL10n.kt` — ru, en, es, it, fr.

### Subscriptions
- `user_entitlements.wearable_insights_enabled` (default `false`) in `012_subscriptions_entitlements.sql`.
- Entitlement service in `backend/app/services/entitlement_service.py`.

### Tests
- Backend: pytest, 26 test files, 70% coverage gate.
- iOS: `HiAirTests/` (session, subscription).
- Android: billing/session unit tests.

### Key docs found
| Doc | Status |
|-----|--------|
| `docs/mvp-spec.md` | Exists — HealthKit explicitly out of MVP |
| `docs/architecture.md` | Exists |
| `docs/risk-thresholds-v1.md` | Exists |
| `docs/feat-personal-patterns-spec.md` | Exists — correlation pattern to mirror |
| `docs/feat-morning-briefing-spec.md` | Exists |
| `docs/privacy-policy-draft.md` | Exists |
| `docs/terms-of-service-draft.md` | Exists |
| `docs/store-metadata-packet.md` | Exists |
| `docs/task-backlog.md` | Exists |
| `docs/_operator/master-gap-report.md` | Exists |

## 3. What Is Missing

| Area | Gap |
|------|-----|
| Database | No `health_data_consents`, `wearable_daily_summaries`, `wearable_hourly_summaries` |
| API | No `/api/v1/wearables/*` endpoints |
| Risk engine | No `personalLoadScore` component |
| iOS | No HealthKit capability, service, or consent UI |
| Android | No Health Connect dependency, service, or consent UI |
| UI | No “Нагрузка сегодня” dashboard card |
| Privacy | No health-data section in policy/store metadata |
| Tests | No wearable API or personal-load engine tests |

## 4. Files To Be Changed / Added

### Backend
- `backend/sql/014_wearable_activity.sql` (new)
- `backend/app/models/wearable.py` (new)
- `backend/app/services/wearable_repository.py` (new)
- `backend/app/services/personal_load_engine.py` (new)
- `backend/app/services/air_risk_engine.py` (extend)
- `backend/app/models/air.py` (extend `RiskAssessmentResult`)
- `backend/app/api/wearables.py` (new)
- `backend/app/main.py` (register router)
- `backend/app/services/privacy_repository.py` (export/delete wearable data)
- `backend/tests/test_wearables_api.py` (new)
- `backend/tests/test_personal_load_engine.py` (new)

### iOS
- `mobile/ios/HiAir/Services/HealthKitService.swift` (new)
- `mobile/ios/HiAir/Screens/WearableConsentView.swift` (new)
- `mobile/ios/HiAir/Screens/DashboardView.swift` (load card)
- `mobile/ios/HiAir/Screens/SettingsView.swift` (Health & Wearables section)
- `mobile/ios/HiAir/Screens/OnboardingView.swift` (optional health step)
- `mobile/ios/HiAir/Networking/APIClient.swift` (wearable endpoints)
- `mobile/ios/HiAir/AppSession.swift` (i18n keys)
- `mobile/ios/project.yml` (HealthKit entitlement)
- `mobile/ios/HiAir/Info.plist` or project.yml (usage strings)

### Android
- `mobile/android/app/build.gradle.kts` (Health Connect dependency)
- `mobile/android/app/src/main/AndroidManifest.xml` (permissions)
- `mobile/android/.../health/HealthConnectService.kt` (new)
- `mobile/android/.../render/WearableLoadCardRenderer.kt` (new)
- `mobile/android/.../render/DashboardScreenRenderer.kt`
- `mobile/android/.../render/SettingsScreenRenderer.kt`
- `mobile/android/.../network/ApiClient.kt`
- `mobile/android/.../i18n/AndroidL10n.kt`

### Docs
- `docs/feat-wearable-activity-insights-spec.md`
- `docs/audit/WEARABLE_ACTIVITY_*_REPORT.md` (8 reports)
- `docs/qa-wearable-activity-checklist.md`
- Updates to privacy, terms, store metadata, beta/qa checklists

## 5. Risks

| Risk | Mitigation |
|------|------------|
| Health data sensitivity | Explicit consent screen; aggregated storage only; delete flow |
| Medical claims | Wellness wording only; guardrails in explanation generator |
| Risk score jumps | Weighted blend; cap personal-load bump to +1 risk level |
| App without permissions | All health paths optional; score = 0 when no data |
| Android onboarding gap | Standalone consent flow from dashboard/settings |
| RLS misconfiguration | Follow 003 direct-ownership pattern on `user_id` |
| Breaking air API | Add optional fields to `RiskAssessmentResult`; no required client changes |

## 6. Privacy / Compliance Approach

1. **Consent before collection** — dedicated screen with skip option.
2. **Data minimization** — daily/hourly aggregates only; no raw HR stream.
3. **User control** — revoke consent, delete stored summaries, OS permission independent.
4. **Backend enforcement** — reject summary sync without active consent.
5. **Export/delete** — extend existing privacy repository.
6. **Store readiness** — update privacy labels and data safety sections.
7. **Wellness disclaimer** — no diagnosis, no emergency alerts.

## 7. Implementation Strategy

1. Schema + RLS (migration 014).
2. Repository + API with validation and consent checks.
3. `personal_load_engine.py` integrated into `air_risk_engine.evaluate_risk` via optional wearable context loaded in `/api/air/current-risk` and `/api/v1/wearables/today`.
4. iOS HealthKit + Android Health Connect services syncing aggregates.
5. Dashboard card + settings + onboarding/consent flow.
6. Tests, docs, validation, commit.

---

**Next step:** Create feature spec and begin backend foundation.
