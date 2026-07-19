# Health Intelligence API Contract

Base: `https://api.hiair.io`  
Auth: `Authorization: Bearer <access_token>`  
Consent version: `health-intelligence-v1`

## Endpoints

| Method | Path | Auth | Premium | Purpose |
|--------|------|------|---------|---------|
| POST | `/api/v1/health/sync` | yes | no | Upsert daily metric + sleep aggregates |
| GET | `/api/v1/health/summary` | yes | no | Day summary + baselines |
| GET | `/api/v1/health/timeline` | yes | no | Env+health+symptoms join |
| GET | `/api/v1/health/availability` | yes | no | Metric availability matrix |
| DELETE | `/api/v1/health/data` | yes | no | Delete health aggregates + revoke |
| GET | `/api/v1/health/insights` | yes | **advanced_insights** | Explainable insight bundle |
| GET | `/api/v1/health/symptoms/taxonomy` | no | no | Symptom catalog |
| POST | `/api/v1/health/symptoms` | yes | no | Comprehensive symptom entry |

## Sync example (synthetic)

```json
{
  "localDate": "2026-07-19",
  "timezone": "Europe/Madrid",
  "platform": "ios",
  "source": "apple_health",
  "clientSyncVersion": "health-intelligence-v1",
  "idempotencyKey": "ios-2026-07-19-demo",
  "metrics": [
    {
      "metricType": "steps",
      "unit": "count",
      "valueTotal": 7500,
      "sampleCount": 1,
      "qualityState": "ok"
    },
    {
      "metricType": "hrv_sdnn",
      "unit": "ms",
      "valueAvg": 45,
      "sampleCount": 3,
      "qualityState": "ok",
      "hrvMethod": "sdnn"
    }
  ],
  "sleep": {
    "localDate": "2026-07-19",
    "totalMinutes": 420,
    "deepMinutes": 70,
    "remMinutes": 90,
    "qualityState": "partial"
  }
}
```

## Rules

- Missing metrics use `qualityState=no_records` — never invent zeros.
- `hrv_sdnn` and `hrv_rmssd` are distinct.
- `body_temperature` and `wrist_temperature` are distinct.
- Idempotency via unique `(user_id, local_date, metric_type, source_platform)` + optional `Idempotency-Key`.
- Do not log exact health values in production request logs.
