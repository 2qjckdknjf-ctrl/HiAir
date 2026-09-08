# AI Innovation Backlog — 2026-09-08

## Purpose

This document captures the highest-value AI/product ideas for HiAir and maps them into a governed backlog. HiAir should remain a trustworthy heat/air-quality decision assistant, not become an open-ended medical chatbot.

## Product principles

- Keep the core promise simple: help the user understand **when it is safer/better to go outside and what to do next**.
- Prefer evidence-backed, plain-language guidance over raw AQI/temperature numbers.
- Treat health/safety guidance as high-risk content: no diagnosis, no unsupported claims, clear uncertainty and source provenance.
- Use on-device/local inference where it materially improves privacy, latency or offline reliability.
- Keep models replaceable and route tasks by privacy, complexity, latency and cost.
- Every AI recommendation should preserve the underlying environmental evidence and explain why it was suggested.

## P0 — Design / implement next

| ID | Capability | Concrete implementation | Definition of done |
|---|---|---|---|
| H-01 | Explainable Risk Briefing | Convert AQI, heat, humidity, time-of-day and forecast context into a short action-oriented explanation: current risk, why, best window, what to avoid and what changed. | Structured explanation schema, source refs, uncertainty, deterministic safety rules + LLM wording layer, eval set. |
| H-02 | Best-Time-to-Go-Outside Optimizer | Rank upcoming time windows using air quality, heat, forecast and user-selected activity constraints. | Time-window scoring, explainability, fallback when data missing, shareable result. |
| H-03 | On-device / Private AI Tier | Use platform-local models for low-risk summarization, rewriting, personalization and offline assistance where quality threshold is met. | Capability detection, privacy-safe fallback, offline tests, no hidden cloud dependency for local mode. |
| H-04 | Health/Safety Content Policy | Separate hard safety rules from generative phrasing; generated output may clarify but not override validated thresholds/policies. | Policy engine, blocked claim classes, disclaimer rules, red-team/eval suite. |
| H-05 | Recommendation Evidence Pack | Each briefing/recommendation stores environmental inputs, source timestamps, rule/model decisions, uncertainty and rendered guidance. | Inspectable debug/evidence object and reproducible recommendation test. |
| H-06 | Mobile AI Skills | Reusable mobile skills: `summarize_risk`, `explain_change`, `rank_time_windows`, `prepare_share_card`, `localize_guidance`, `detect_missing_data`, `generate_morning_brief`. | Versioned schemas + deterministic preconditions + tests. |
| H-07 | AI Visibility / GEO Baseline | Track whether HiAir is surfaced/cited for relevant informational queries and identify missing authority, original evidence and third-party references. | Defined query set, monthly/weekly baseline, competitor comparison and action backlog. |
| H-08 | Evidence-led Content Engine | Turn trusted environmental/behavioral data and recurring user questions into reviewed articles/videos/social assets with clear sources and no medical overclaiming. | Research→brief→claim check→human approval→publish→measurement loop. |
| H-09 | ROMA Mobile Integration | Use independent QA/evidence checks for iOS/Android AI flows: crashes, regressions, accessibility, localization, offline behavior and recommendation consistency. | CI/QA contract + release evidence for AI-specific user journeys. |

## P1 — Build after P0 safety/evidence contracts are stable

| ID | Capability | Concrete implementation | Expected effect |
|---|---|---|---|
| H-10 | Personal Context Preferences | User-selected sensitivity/activity preferences (e.g. walking, running, child-friendly outing) adjust presentation and time-window ranking without making medical diagnoses. | More useful recommendations while staying within product scope. |
| H-11 | Adaptive Morning Briefing | Morning summary prioritizes only meaningful changes, best windows and action items rather than repeating static metrics. | Higher daily utility and retention. |
| H-12 | Smart Notification Policy | Trigger alerts only when a meaningful threshold/change affects a planned activity or previously good window. | Lower notification fatigue. |
| H-13 | Model Router | Local/cheap/frontier model selection based on privacy, latency, language, complexity and evidence risk. | Lower cost and better resilience. |
| H-14 | AI Cost/Value Telemetry | Track inference cost, latency, fallback frequency, user engagement and recommendation acceptance/ignore signals. | Tune where AI adds value and remove wasteful generation. |
| H-15 | Multilingual Plain-language Layer | Preserve the same safety meaning across supported languages while adapting style/reading level. | Better accessibility and international usefulness. |
| H-16 | Shareable Risk Cards | Generate evidence-backed concise cards for messaging/social sharing without sensationalism. | Organic distribution and clearer communication. |
| H-17 | Product-to-Content Loop | Aggregate anonymized, privacy-safe patterns such as common questions and recurring environmental scenarios into content opportunities. | Content reflects real user needs. |

## P2 — Explore carefully

| ID | Capability | Constraint before adoption |
|---|---|---|
| H-18 | Conversational AI assistant | Keep bounded to environmental guidance; no diagnosis/treatment; enforce tool/rule grounding and safety policy. |
| H-19 | Sensor / wearable integration | Only when data quality, consent, platform permissions and user value are clear. |
| H-20 | Highly personalized risk model | Requires validated evidence, explicit scope, privacy/legal review and no unsupported medical inference. |

## Architecture direction

```text
Environmental Data / Forecasts / User Preferences
                         │
                         ▼
                 Deterministic Risk Logic
                         │
                         ▼
             Time-window / Recommendation Engine
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
     Local AI        Cloud AI        Localization
        │                │                │
        └────────────────┼────────────────┘
                         ▼
                Safety / Claim Policy
                         │
                         ▼
                 Explainable Briefing
                         │
                         ▼
                  Evidence Pack
                         │
                         ▼
                 ROMA / Release QA
```

## Growth integration

HiAir should connect to Growth OS for:

- GEO/AI visibility tracking;
- evidence-led content opportunities;
- competitor/category intelligence;
- attribution from content to activation;
- claim-safe multi-format distribution.

Growth OS may propose content/actions, but HiAir safety/claim policy remains authoritative for health/environment wording.

## Recommended delivery sequence

1. Formalize explanation/recommendation evidence schema and safety policy.
2. Build best-time-window optimizer and explainable risk briefing.
3. Add mobile AI skills and local/private inference tier.
4. Connect ROMA AI-flow QA and regression evidence.
5. Establish GEO baseline and evidence-led content loop through Growth OS.
6. Add adaptive briefing, smart notifications, model routing and cost telemetry.
7. Explore bounded conversational UI only after grounding/safety evals are strong.

## Explicit non-goals

- No medical diagnosis or treatment recommendations.
- No generative model overriding validated risk thresholds.
- No fabricated health statistics, citations or certainty.
- No notification spam to maximize engagement.
- No cloud upload of sensitive context when a local/private path is promised.
