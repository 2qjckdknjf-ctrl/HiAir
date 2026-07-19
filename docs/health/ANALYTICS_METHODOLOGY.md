# Analytics Methodology

## Rules

1. Missing data is never coerced to zero.
2. No causal claims («вызвал» / «caused»).
3. Wellness language only — no diagnoses, no medication advice.
4. Minimum samples:
   - associations: ≥5 symptom days
   - simple trends: ≥7 days
   - stronger confidence: ≥14 days (prefer 30-day window)

## Analyses

| Analysis | Inputs | Output |
|----------|--------|--------|
| Trends | steps, RHR, HRV, sleep | direction vs earlier baseline |
| Same-day association | PM2.5 / heat / AQI × symptoms | hit/total days wording |
| Lagged | short sleep → same/next day severity | observed co-occurrence |
| Combined | short sleep + high AQI × fatigue | multi-factor observation |
| Baseline deviation | resting HR vs personal median | elevated-from-baseline card |

## Confidence

`preliminary` → `moderate` → `stronger` (or `insufficient` when below floors).

Each card includes supporting factors, limitations, and «why shown».
