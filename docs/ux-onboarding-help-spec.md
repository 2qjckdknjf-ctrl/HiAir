# HiAir UX Onboarding + Help Spec

## Problem
On first launch, users do not quickly understand what HiAir is, what problems it solves, how to read key metrics, or what to do next.

## Solution
Implement a first-run educational layer across onboarding, dashboard checklist, in-context term explanations, help guide, and actionable empty states.

## User journey
1. User signs in.
2. User sees 6-step onboarding (first run only).
3. User lands on dashboard with "How to start" checklist.
4. User can tap info icons for term definitions.
5. User can open "HiAir Guide" in Settings anytime.
6. User can reopen onboarding from Settings.

## Onboarding screens
1. **Intro** - what HiAir is and why it matters.
2. **Problems solved** - heat, PM2.5, ozone/smoke, sensitive groups, outdoor activity.
3. **Persona** - select who user is protecting.
4. **Daily reading model** - Risk Score, hourly safe windows, recommendations, notifications.
5. **Permissions rationale** - location + notifications with allow/later options.
6. **Done** - explicit next action to open forecast.

## Home checklist
- Check current risk.
- Open hourly forecast.
- Read recommendations.
- Set up profile.
- Turn on notifications.

Behavior:
- Visible for new users.
- Items can be toggled done.
- User can hide checklist.

## In-UI term explanations
Info affordances for:
- Risk Score
- AQI
- PM2.5
- Ozone
- Heat Index
- Safe Window
- Recommendations

## HiAir Guide
Settings entry point with short sections:
- What is HiAir
- Problems solved
- Who it helps
- How to read home screen
- Risk Score meaning
- AQI/PM2.5/ozone/humidity/heat basics
- Hourly forecast usage
- Safe windows
- Symptom log usage
- Notification setup
- High-risk behavior
- Not a medical replacement
- FAQ

## Empty states
Action-oriented states for:
- Missing profile
- Data/API unavailable
- Notifications off
- Missing location
- Empty symptom log

Each includes:
- what happened,
- why it matters,
- recommended next action.

## Localization
- New UX copy keys implemented for RU and EN.
- No hardcoded user-facing text introduced in newly added UX flows.

## Acceptance criteria
- First-run user can explain app purpose and first action in < 60 sec.
- Onboarding is first-run only and can be reopened from Settings.
- Dashboard has starter checklist.
- Key terms are explainable in one tap.
- Guide exists and is discoverable in Settings.
- Empty states are actionable.
- App builds successfully after changes.
