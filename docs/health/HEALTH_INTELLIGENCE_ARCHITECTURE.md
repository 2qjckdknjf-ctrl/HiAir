# Health Intelligence Architecture

**Version:** health-intelligence-v1  
**Date:** 2026-07-19  
**Status:** Engineering complete — device health-data verification pending

## Pipeline

```
Apple Health / Health Connect
  → progressive consent (tiers 1–4)
  → on-device aggregation (never raw HR streams)
  → POST /api/v1/health/sync
  → wearable_metric_daily + wearable_sleep_summaries + wearable_sync_state
  → legacy wearable_daily_summaries (personalLoad)
  → unified timeline + baselines
  → explainable insights (trends / associations / insufficient)
  → recommendations (wellness language only)
```

## API contract

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/health/sync` | Upsert metric + sleep summaries |
| GET | `/api/v1/health/summary` | Today / date summary + baselines |
| GET | `/api/v1/health/timeline` | Env + health + symptoms join |
| GET | `/api/v1/health/availability` | Metric availability matrix |
| DELETE | `/api/v1/health/data` | Delete health aggregates + revoke |
| GET | `/api/v1/health/insights` | Explainable insight bundle |
| GET | `/api/v1/health/symptoms/taxonomy` | Comprehensive symptom catalog |
| POST | `/api/v1/health/symptoms` | Rich symptom entry |
| PATCH/DELETE | `/api/v1/health/symptoms/{id}` | Edit / soft-delete |
| POST/GET | `/api/v1/health/symptoms/custom` | Custom symptoms |
| POST/GET | `/api/v1/health/symptoms/favorites` | Favorites |

Legacy wearables-v1 endpoints remain for personalLoad.

## Privacy

- Explicit consent required before sync.
- Aggregates only; no ECG/GPS routes/raw HR.
- Missing ≠ 0.
- Quality states distinguish permission / no records / unsupported / sync error.
- Privacy export includes metric/sleep/sync tables.
- Account delete removes health tables.
- Analytics events never include exact health values.
- Sensitive metrics (BP/glucose) opt-in only and excluded from risk score.

## Analytics methodology

- Minimum 5 symptom days for associations; 7 for simple trends; 14–30 for stronger.
- Same-day and next-day windows.
- Confidence: preliminary / moderate / stronger / insufficient.
- Wording: «наблюдается связь» — never causal diagnosis.

See also:

- [CANONICAL_METRIC_CATALOG.md](./CANONICAL_METRIC_CATALOG.md)
- [PLATFORM_CAPABILITY_MATRIX.md](./PLATFORM_CAPABILITY_MATRIX.md)
- [STAGE0_TRUTH_AUDIT.md](./STAGE0_TRUTH_AUDIT.md)
