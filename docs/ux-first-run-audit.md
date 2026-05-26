# HiAir First-Run UX Audit

## Scope
- iOS first-run path: auth -> onboarding -> dashboard/planner/insights/symptoms/settings.
- Product comprehension in first 30-60 seconds.
- Localization and copy quality for RU/EN.
- Empty states, help/reference discoverability, and navigation resilience.

## Key findings before implementation

### 1) First run and positioning
- Onboarding existed, but was technical and form-like (persona/sensitivity/lat/lon/profile id).
- It did not clearly answer "what is HiAir", "why use it", "what problem it solves", and "what to do first".
- Profile ID input on first run created friction and confusion.

### 2) Home screen guidance
- No explicit "where to start" checklist for new users.
- No lightweight in-context education for Risk Score/AQI/PM2.5/Ozone/Heat Index/Safe Window/Recommendations.
- Terminology understanding depended on prior domain knowledge.

### 3) Empty states and actionability
- Profile-missing states existed but were partially technical and not always actionable.
- Temporary API/data unavailability states were generic.
- Symptom log and notification-off states lacked explicit "why this matters" guidance.

### 4) Help/reference
- No dedicated in-app "HiAir Guide" with short human-readable explanations.
- User had no single place to quickly re-check key definitions and safety behavior.

### 5) Navigation and first-run continuity
- Onboarding completion persisted, but logout reset onboarding state, causing repeated onboarding.
- No explicit "open onboarding again" path in Settings.

### 6) Localization
- Core app had RU/EN localization foundation.
- New first-run educational copy needed expansion through localization keys (no hardcoded UX text).

## UX/Product goals derived from audit
- Deliver a 6-step educational onboarding with plain language and permission context.
- Add first-run checklist on dashboard with progress and dismiss.
- Add in-UI info affordances for critical terms.
- Add in-app reference section ("HiAir Guide").
- Upgrade empty states with: what happened -> why important -> what to press next.
- Ensure onboarding is first-run only, but reopenable from Settings.

## Acceptance focus for QA
- New user understands purpose/value/workflow in under 60 seconds.
- Dashboard explains first actions without external guidance.
- Key terms are explainable in one tap.
- Empty states are non-dead-end and actionable.
- RU/EN copy is complete for newly introduced UX surfaces.
