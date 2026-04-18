# HiAir AI MVP Architecture

## Architecture principle

HiAir AI MVP is intentionally split into three layers:

1. Deterministic Core (source of truth)
2. AI Personalization Layer (humanized but bounded)
3. AI Interaction Layer (cards/timeline/alerts surfaces)

The LLM is never used for safety-critical scoring. It only explains deterministic outputs.

## Layer A: Deterministic Core

Core module: `backend/app/services/air_risk_engine.py`

Inputs:
- Temperature, feels-like, humidity
- AQI, PM2.5, PM10, ozone
- UV, wind, time-of-day projection
- Geolocation + profile modifiers

Outputs:
- `overallRisk`, `heatRisk`, `airRisk`, `outdoorRisk`, `indoorVentilationRisk`
- `safeWindows[]`
- `recommendationFlags[]`
- `reasonCodes[]`

Properties:
- rule-based
- deterministic
- testable
- explainable (via reason codes)

## Layer B: AI Personalization

Modules:
- `air_recommendation_engine.py`
- `ai_explanation_service.py`

Responsibilities:
- Transform deterministic risk into profile-aware actions.
- Produce short explanation text in calm/action-first tone.
- Enforce guardrails:
  - no diagnosis
  - no treatment advice
  - no emergency claims
  - forbidden phrase check

Fallback mode:
- If LLM fails/unavailable, deterministic template explanation is returned.
- UI continues to work without AI outage.

Prompt/version governance:
- Prompt metadata is versioned and persisted (`ai_prompt_versions`).
- Every explanation generation is logged with fallback/guardrail flags (`ai_explanation_events`).

## Layer C: Interaction

Backend contracts:
- `GET /api/air/current-risk?profileId=...`
- `GET /api/air/day-plan?profileId=...`
- `GET /api/air/recommendations?profileId=...`
- `POST /api/air/recompute-risk`
- `POST /api/alerts/evaluate`
- `POST /api/symptoms`
- `GET /api/symptoms/history?profileId=...`

UI surfaces integrated in iOS MVP:
- Home risk card (overall risk + explanation + actions + nearest safe window)
- Daily timeline (hourly risk + safe windows + ventilation windows)
- Alert preferences (push, threshold, quiet hours, profile-based alerting)
- Symptom quick log (1-2 tap shortcuts)

## Data model

Migration: `backend/sql/003_ai_mvp_architecture.sql`

New or extended entities:
- Extended `profiles` (acts as user_profiles context)
- Extended `environment_snapshots`
- New `risk_assessments`
- New `ai_recommendations`
- New `alert_events`
- Extended `symptom_logs` for quick symptom entries/history
- Extended `user_settings` for quiet hours/profile alerting

## Alert orchestration

Module: `backend/app/services/alert_orchestrator.py`

Rules:
- evaluate risk change vs previous assessment
- map to severity (`low..critical_non_medical`)
- dedupe by deterministic key
- enforce quiet hours
- persist decision trail in `alert_events`

## Safety controls

- Deterministic core is mandatory for all scoring.
- Prompt guardrails are embedded in AI explanation request.
- Output validator rejects unsafe medical phrasing.
- Fallback template ensures continuity.
- Logging covers risk, AI failures, and fallback path.
- AI observability endpoints expose runtime counters and DB-backed AI summary:
  - `GET /api/observability/metrics`
  - `GET /api/observability/ai-summary`
  - `GET /api/observability/ai-summary-detailed`
