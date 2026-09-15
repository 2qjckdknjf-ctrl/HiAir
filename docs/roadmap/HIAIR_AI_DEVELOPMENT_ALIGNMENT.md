# HiAir AI Development Alignment

**Status:** roadmap constraint; does not widen the current release.  
**Date:** 2026-09-15

## Product priority

HiAir is a personal environmental decision product. The near-term goal is not "more agents"; it is trustworthy real data, reliable recommendations, production/store/device readiness, personalization and retention.

Grow OS/ROMA own cross-project agent governance. HiAir should consume those platform capabilities later rather than build a second control plane.

## Ordered tasks

### HIAIR-REL-001 — Finish current release/trust gates (P0)

Keep the current release/master-upgrade program first:
- live environmental data truth;
- production API/deploy smokes;
- auth/subscription integrity;
- physical-device QA and store readiness;
- no production mock/fake data;
- honest unavailable/null behavior.

**Gate:** existing release scripts/audits truthfully reach their required readiness state. Do not introduce new agentic features to bypass this work.

### HIAIR-PRED-002 — Personal Environmental Forecast (P1, after release gate)

Unify available forecast inputs into an evidence-backed recommendation layer:

```text
weather forecast
 + AQI / pollutants
 + pollen when available
 + user location / saved place
 + planned activity
 + consented personal context
 -> personal environmental forecast
 -> best time window / day plan / recommendation
```

Requirements:
- never infer unavailable hazards as zero;
- expose uncertainty/source/freshness;
- preserve wellness-only wording;
- no emergency/diagnostic claims;
- use existing planner/risk/recommendation endpoints before creating parallel APIs.

**Gate:** recommendation quality is measurably better than current conditions-only guidance and remains useful when optional health/wearable permissions are denied.

### HIAIR-VOICE-003 — Voice/agent experiment (P2)

Only after HIAIR-PRED-002 proves value. Voice/agent interaction must be a thin interface over the same recommendation engine, for example "Can I run for 40 minutes now?". Do not create a separate source of truth or a second risk engine.

### HIAIR-GROW-004 — Grow OS integration (P2)

Expose project/release/quality evidence to Grow OS. Any future agent runtime should use Grow OS identity/policy/observability rather than storing canonical project state inside a model provider.

## Explicitly deferred

- multi-agent swarms inside HiAir;
- new foundation-model work for its own sake;
- own weather model/GPU stack;
- model-specific persistence;
- new agent screens before release/trust gates;
- medical diagnosis/emergency behavior.

## Agent rules

Before Cursor/Codex implements AI/agent work in HiAir:

1. read root `AGENTS.md`;
2. read this file;
3. verify HIAIR-REL-001 status before starting later tasks;
4. reuse existing forecast/risk/planner/recommendation services;
5. implement one additive slice with tests and truthful provenance;
6. do not start the next blocked task automatically.
