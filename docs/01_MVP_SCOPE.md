# 01 MVP Scope

## In Scope (MVP / Closed Beta)
- Account auth (signup/login/refresh/logout).
- Profile onboarding (persona, sensitivity, location).
- Dashboard current risk + recommendations.
- Daily planner + safe windows.
- Symptom logging.
- Insights (personal patterns) when enough data exists.
- Morning briefing schedule management.
- Privacy export/delete endpoints.

## Out of Scope / Scaffold
- Final paid subscription production billing lifecycle.
- Production APNs/FCM credential rollout and live push at scale.
- Full legal finalization and store-console submission operations.

## Safety Scope
- Deterministic risk score remains source of truth.
- AI/LLM layer only explains deterministic output and passes wording guardrails.
