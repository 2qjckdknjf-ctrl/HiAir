# STAGE 0 — Health Intelligence Truth Audit

**Date:** 2026-07-19  
**Branch:** `feat/health-intelligence-expansion`  
**Verdict before expansion:** PARTIAL foundation (wearables-v1) — not full health intelligence.

## Coverage matrix (before)

| Metric | Backend | iOS read | Android read | Permission | UI | Analytics |
|--------|---------|----------|--------------|------------|----|-----------|
| Steps | IMPLEMENTED | IMPLEMENTED | IMPLEMENTED | IMPLEMENTED | PARTIAL | PARTIAL (load) |
| Heart rate avg/min/max | IMPLEMENTED | IMPLEMENTED | IMPLEMENTED | IMPLEMENTED | PARTIAL | PARTIAL (load) |
| Resting HR | IMPLEMENTED | IMPLEMENTED | IMPLEMENTED | IMPLEMENTED | PARTIAL | PARTIAL (baseline) |
| HRV | PARTIAL (consent flag) | MISSING | MISSING | STUB | MISSING | MISSING |
| Sleep duration/stages | PARTIAL (consent flag) | MISSING | MISSING | STUB | MISSING | MISSING |
| Distance / active energy | MISSING | MISSING | MISSING | MISSING | MISSING | MISSING |
| Workouts | MISSING | MISSING | MISSING | MISSING | MISSING | MISSING |
| Floors / stand | MISSING | MISSING | MISSING | MISSING | MISSING | MISSING |
| Respiratory rate | MISSING | MISSING | MISSING | MISSING | MISSING | MISSING |
| SpO₂ | MISSING | MISSING | MISSING | MISSING | MISSING | MISSING |
| Body / wrist temperature | MISSING | MISSING | MISSING | MISSING | MISSING | MISSING |
| VO₂ max | MISSING | MISSING | MISSING | MISSING | MISSING | MISSING |
| Symptoms (comprehensive) | PARTIAL (4 booleans + quick type) | PARTIAL (4) | PARTIAL (4) | N/A | PARTIAL | PARTIAL (4) |
| Personal insights | PARTIAL (Pearson env↔4 symptoms) | PARTIAL | PARTIAL | Premium gate | PARTIAL | PARTIAL |
| Progressive consent UX | PARTIAL (single screen) | PARTIAL | PARTIAL | PARTIAL | PARTIAL | N/A |
| Incremental sync / anchors | MISSING | MISSING | MISSING | N/A | MISSING | N/A |
| Metric-level delete/export | PARTIAL (all wearables) | PARTIAL | PARTIAL | PARTIAL | PARTIAL | N/A |

## Existing surfaces

| Area | Path | Status |
|------|------|--------|
| Migration | `backend/sql/014_wearable_activity.sql` | IMPLEMENTED (narrow) |
| API | `POST/DELETE /api/v1/wearables/*` | IMPLEMENTED |
| Models | `backend/app/models/wearable.py` | IMPLEMENTED (narrow) |
| Personal load | `backend/app/services/personal_load_engine.py` | IMPLEMENTED |
| Correlation | `backend/app/services/correlation_engine.py` | PARTIAL (env↔4 symptoms, COALESCE→0) |
| iOS HealthKit | `mobile/ios/HiAir/Services/HealthKitService.swift` | PARTIAL (steps/HR/resting) |
| Android HC | `mobile/android/.../HealthConnectService.kt` | PARTIAL (steps/HR/resting) |
| Symptoms UI | iOS/Android 4 pills | PARTIAL |
| Insights UI | Personal patterns list | PARTIAL |

## Critical gaps

1. No sleep/HRV/SpO₂/respiratory/temperature/workout pipeline.
2. Symptom taxonomy too small for air/heat wellness use cases.
3. Insights ignore wearable metrics and treat missing env as zero.
4. No progressive per-category consent or availability matrix UI.
5. No incremental sync anchors / change tokens.
6. No unified daily timeline joining environment + health + symptoms.
