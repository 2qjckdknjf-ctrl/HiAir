# Feature Spec: Wearable & Activity Intelligence v1

**Product:** HiAir  
**Version:** wearables-v1  
**Status:** Implementation  
**Date:** 2026-06-04

## 1. Product Goal

HiAir accounts for personal activity load alongside heat, AQI, humidity, and symptoms:

- Steps today (and last hour / last 3 hours when available)
- Average and max heart rate
- Resting heart rate and deviation from personal baseline
- Wellness-oriented risk amplification — not medical diagnosis

## 2. MVP Scope (In)

| Capability | Required |
|------------|----------|
| Read steps | Yes |
| Read heart rate | Yes |
| Read resting heart rate (if available) | Yes |
| Consent screen with skip | Yes |
| Settings: connect / disconnect / delete | Yes |
| Backend sync of aggregates only | Yes |
| `personalLoadScore` in risk engine | Yes |
| User-facing explanation of elevated load | Yes |
| iOS Apple Health | Yes |
| Android Health Connect | Yes |
| RU / EN / ES localization (extend IT/FR if keys exist) | Yes |

## 3. Out of Scope (v1)

- Medical diagnoses or emergency alerts
- Continuous raw heart-rate stream storage
- Clinical / doctor logic
- HRV / sleep / skin temperature as required inputs
- Premium wearable reports (entitlement flag exists but not gated in v1)
- Google Fit (use Health Connect only)

## 4. Safety Wording

### Allowed
- “Пульс выше вашей обычной нормы.”
- “Организм может быть перегружен.”
- “Рекомендуем снизить активность.”
- “HiAir даёт wellness-рекомендации, а не медицинский диагноз.”
- “Сегодня высокая активность на фоне жары.”
- “При текущем AQI лучше снизить интенсивную активность на улице.”

### Forbidden
- “У вас тахикардия.”
- “У вас сердечная проблема.”
- “Срочно обратитесь в больницу.”
- “Мы диагностировали…”
- Any ICD/clinical terminology

## 5. Data Minimization

| Stored | Not stored |
|--------|------------|
| Daily summary (steps, HR avg/min/max, resting HR) | Raw HR samples |
| Hourly summary (steps, HR avg/max) | Continuous streams |
| Consent record with version + timestamps | Device identifiers beyond platform/source |

User may delete all wearable summaries via `DELETE /api/v1/wearables/data`.

## 6. Risk Integration

```
personalLoadScore = 0..100 (0 when no data)

finalNumericScore =
  environmentalRiskScore * 0.65 +
  personalLoadScore * 0.25 +
  symptomRiskScore * 0.10
```

Environmental risk remains primary. Personal load amplifies when heat/AQI + activity align. Missing health data does not penalize the user.

### Personal load rules (v1)

1. **Steps + heat:** >6000 + HI≥30 → +10; >8000 + HI≥32 → +15; >10000 + HI≥34 → +20
2. **Recent steps:** >2000 last hour + HI≥30 → +10; >2500 last hour + AQI≥100 → +10
3. **Heart rate:** max>130 + HI≥30 → +10; elevated avg + heat/AQI → +10
4. **Resting HR:** >baseline7d+8 → +15; >baseline30d+10 → +15 (skip if no baseline)
5. **AQI + activity:** AQI≥100 + steps>6000 → +10; AQI≥150 + steps>4000 → +15
6. **Symptoms:** no duplicate scoring; add explanation context only

## 7. API Surface

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/wearables/consent` | Save/update consent |
| DELETE | `/api/v1/wearables/consent` | Revoke consent |
| POST | `/api/v1/wearables/daily-summary` | Upsert daily aggregate |
| POST | `/api/v1/wearables/hourly-summary` | Upsert hourly aggregate |
| GET | `/api/v1/wearables/today` | Today activity + consent + load summary |
| DELETE | `/api/v1/wearables/data` | Delete all wearable summaries |

All endpoints require authenticated user; `user_id` from token only.

## 8. Mobile UX

### Consent flow
- Title: “Подключите здоровье и активность”
- Connect / Skip buttons
- Available from onboarding (iOS step 4.5 or post-permissions) and dashboard/settings

### Dashboard card: “Нагрузка сегодня”
States: connected with data, not connected, permission denied, data unavailable, sync failed (non-blocking)

### Settings: “Health & Wearables”
Status, toggles, disconnect, delete health data (confirmation dialog)

## 9. Acceptance Criteria

- [ ] App works without health permissions
- [ ] Feature explained before permission request
- [ ] User can revoke access and delete stored summaries
- [ ] `personalLoadScore` applied only when data available
- [ ] No medical claims in UI or API explanations
- [ ] Backend rejects sync without active consent
- [ ] Tests pass
- [ ] Privacy/store docs updated

## 10. Future (v2)

- HRV, sleep, skin temperature
- Personal trends and baselines UI
- Premium wearable insight reports
- Family profile wearables
