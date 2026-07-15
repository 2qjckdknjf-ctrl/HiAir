# Personal Patterns foundation

Rule-based wellness insights after 7+ observation days:

1. Symptoms more common when AQI above threshold
2. Risk higher at specific time of day
3. Resting heart rate correlates with heat when wearable data exists

## API

`GET /api/insights/personal-patterns?profile_id=...`

## Guardrails

- No medical diagnoses
- Low-data state: "need more observation days"
- Minimum 3 insight types supported when data allows
