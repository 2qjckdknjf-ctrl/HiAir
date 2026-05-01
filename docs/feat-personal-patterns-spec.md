# Feature Spec: Personal Patterns Insights

Status: spec frozen for cycle "aurora-calm + insights"
Owner: backend + mobile
Last updated: 2026-05-01

## Goal

Show each user how environmental factors (PM2.5, ozone, temperature, humidity,
AQI) personally correlate with their logged symptoms (cough, wheeze, headache,
fatigue, sleep_quality) over a rolling window.

This is the unique switching cost of HiAir versus generic AQI apps. No competitor
gives the user a personal-level statistical readout of their own life.

## Non-goals

- Causality claims. We only show correlation.
- Medical interpretation. Wellness positioning stays.
- Predictive modelling. That is a future cycle.
- Cross-user aggregation. Strictly per-profile.

## User-facing surface

New Insights tab in bottom navigation (5 tabs total now: Dashboard, Planner,
Insights, Symptoms, Settings).

Insights screen has:
1. "This week" header — symptom log count, average risk, streak
2. "Personal patterns" section — list of significant correlations with AI text
3. "Recent days" timeline — 7 days of risk + symptom dots on a shared axis
4. Empty state — when fewer than 14 data points: "Log a few more days to unlock
   personal patterns"

## Statistical method

Pure-Python Pearson correlation. No scipy dependency.

Implementation in `backend/app/services/correlation_engine.py`:

```python
def pearson(xs: list[float], ys: list[float]) -> float:
    n = len(xs)
    if n < 2: return 0.0
    mean_x = sum(xs) / n
    mean_y = sum(ys) / n
    num = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
    den_x = sum((x - mean_x) ** 2 for x in xs) ** 0.5
    den_y = sum((y - mean_y) ** 2 for y in ys) ** 0.5
    if den_x == 0 or den_y == 0: return 0.0
    return num / (den_x * den_y)
```

Significance: two-tailed p-value via t-distribution approximation. For n >= 14
we use Student's t with df = n-2 and a lookup table for p<0.05 / p<0.01
thresholds. A from-scratch implementation lives in the same module.

## Inclusion criteria

A correlation is shown only if:
- sample_size >= 14 (paired daily aggregates)
- |coefficient| >= 0.30
- p_value < 0.05

If no correlation passes, the section shows the empty state.

## Factor pairs

Environmental factors (daily aggregate, daytime average):
- pm25, ozone, temperature_c, humidity_percent, aqi

Symptom factors (daily aggregate):
- cough_count, wheeze_count, headache_count, fatigue_count
- sleep_quality (latest entry of the day)

Total pairs: 5 × 5 = 25 per profile per window. Negligible compute.

## Data model

Migration `006_personal_correlations.sql`:

```sql
CREATE TABLE IF NOT EXISTS personal_correlations (
    id UUID PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    factor_a TEXT NOT NULL,
    factor_b TEXT NOT NULL,
    coefficient DOUBLE PRECISION NOT NULL,
    p_value DOUBLE PRECISION NOT NULL,
    sample_size INT NOT NULL,
    window_days INT NOT NULL,
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_personal_correlations_profile_computed
    ON personal_correlations(profile_id, computed_at DESC);

CREATE INDEX IF NOT EXISTS idx_personal_correlations_window
    ON personal_correlations(profile_id, window_days, computed_at DESC);
```

Recompute job overwrites previous results for the same `(profile_id, window_days)`
tuple by inserting a new row and pruning rows older than 7 days.

## API contract

### GET /api/insights/personal-patterns

Query params:
- `profile_id` (required, UUID)
- `window_days` (optional, default 30, allowed values 30 / 60 / 90)

Headers:
- `Authorization: Bearer <token>` (required)
- `Accept-Language: ru` or `en` (defaults to user's preferred_language)

Response 200:
```json
{
  "profile_id": "uuid",
  "window_days": 30,
  "computed_at": "2026-05-01T08:00:00Z",
  "sample_size": 22,
  "patterns": [
    {
      "factor_a": "pm25",
      "factor_b": "wheeze_count",
      "coefficient": 0.62,
      "p_value": 0.003,
      "direction": "positive",
      "strength": "moderate",
      "human_readable": "Когда уровень PM2.5 выше 35, ты чаще логируешь свистящее дыхание.",
      "ai_explanation": "За последние 30 дней просматривается связь между PM2.5 и свистящим дыханием. Это наблюдение, не диагноз — стоит обсудить с врачом, если эпизоды беспокоят."
    }
  ],
  "empty_reason": null
}
```

If sample_size < 14:
```json
{
  "profile_id": "uuid",
  "window_days": 30,
  "sample_size": 6,
  "patterns": [],
  "empty_reason": "insufficient_data"
}
```

### Errors

| Status | Reason                              |
|--------|-------------------------------------|
| 401    | Missing or invalid auth             |
| 403    | profile_id not owned by user        |
| 422    | Invalid window_days                 |
| 503    | Database unavailable                |

## AI explanation layer

On-demand generation per request, not background. AI explanation receives the
deterministic correlation object plus profile context plus target language.

New prompt key: `personal_pattern_v1` registered via `ensure_prompt_version`.

Guardrails (added to `FORBIDDEN_PHRASES`):
- "вызывает", "приводит к", "из-за этого", "лечит"
- "causes", "leads to", "because of", "treats", "cures"

Output validation rejects any text containing the above. Falls back to template
text in the user's language. Fallback template lives in `localization.py` keys:
- `pattern.fallback.positive`
- `pattern.fallback.negative`

Response always returns successfully — fallback covers LLM outage.

## Privacy

`personal_correlations` rows are user-linked through profile. They must be
included in:
- `GET /api/privacy/export` (under key `personal_correlations`)
- `POST /api/privacy/delete-account` (CASCADE via profile FK already covers this)

`docs/data-retention-matrix.md` updated with row for `personal_correlations`:
retention 7 days for raw rows, recomputed daily.

## Background recompute

Script `backend/scripts/recompute_correlations.py`:
- Iterates all profiles with at least 1 symptom log in last 30 days
- Calls `correlation_engine.compute_correlations(profile_id, window_days)`
  for each window in [30, 60, 90]
- Persists results
- Logs run summary to ops observability

Cron: daily at 04:00 UTC. Documented in `docs/ops-correlation-runbook.md`
(written in this cycle).

## Localization keys (added in this cycle)

```
pattern.empty.title
pattern.empty.body
pattern.window_30
pattern.window_60
pattern.window_90
pattern.strength.weak
pattern.strength.moderate
pattern.strength.strong
pattern.fallback.positive
pattern.fallback.negative
pattern.legal.disclaimer
nav.insights
insights.this_week
insights.symptom_logs
insights.avg_risk
insights.streak
insights.timeline_title
insights.empty_data_hint
```

All added to both `ru` and `en` in `backend/app/services/localization.py`,
mirrored in `mobile/ios/HiAir/AppSession.swift` and
`mobile/android/app/src/main/java/com/hiair/ui/i18n/AndroidL10n.kt`.

## Tests

- `backend/tests/test_correlation_engine.py`
  - Pearson on known fixture (perfect positive, perfect negative, zero)
  - Edge cases: empty, single point, constant series
  - p-value approximation matches reference within 0.005
- `backend/tests/test_insights_api.py`
  - Auth required
  - Ownership enforced
  - window_days validation
  - Empty state when sample_size < 14
  - Includes AI explanation field when patterns exist
- `backend/tests/test_pattern_explanation_guardrails.py`
  - Rejects causal phrasing
  - Falls back to template on missing OPENAI_API_KEY
  - Returns text in requested language
- `backend/tests/test_recompute_correlations_script.py`
  - Dry-run mode lists eligible profiles
  - Persistence end-to-end with fixture data

## Verification at cycle exit

- All four test modules pass
- `scripts/smoke_db_flow.py` extended with insights endpoint check
- `scripts/beta_preflight.py` includes insights check
- Privacy export includes `personal_correlations` for an account with patterns
- Manual QA: full Insights screen on iOS + Android with both ru and en

## Out of scope for this cycle

- Multi-profile insights
- Pattern push notifications ("New pattern detected")
- Causal hypothesis testing beyond Pearson
- Sharing patterns externally
