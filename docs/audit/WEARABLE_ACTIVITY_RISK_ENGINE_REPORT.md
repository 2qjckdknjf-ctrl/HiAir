# Wearable Activity — Risk Engine Report

**Module:** `backend/app/services/personal_load_engine.py`  
**Integration:** `air_risk_engine.evaluate_risk(..., personal_load=...)`

## personalLoadScore

- Range: 0–100
- Returns 0 when consent inactive or no wearable data
- Rules implemented per spec: steps+heat, recent steps, HR max, resting HR baseline, AQI+activity
- Symptom duplication avoided; context explanation only when load + symptoms

## Weighted Blend (reference)

```
finalNumeric = env*0.65 + personalLoad*0.25 + symptoms*0.10
```

Discrete air engine uses `personal_load_risk_bump()` to add at most +1 overall risk level when score ≥ 25.

## RiskAssessmentResult Extension

Optional `personalLoad` field:

- score, level, explanations, reasonCodes

Loaded in `/api/air/current-risk` via `wearable_service.build_personal_load_input`.

## Explanations (wellness-only)

Examples generated:

- "Сегодня высокая активность на фоне жары."
- "Пульс выше вашей обычной нормы."
- "Данных о здоровье нет — анализ основан на погоде и качестве воздуха."

Forbidden phrases filtered in `_sanitize_explanations`.

## Tests

`backend/tests/test_personal_load_engine.py` — 10 unit tests covering all major rules and medical wording guard.
