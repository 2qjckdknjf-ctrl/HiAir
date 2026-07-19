# Canonical Health Metric Catalog

**Consent version:** `health-intelligence-v1`  
**Storage policy:** daily/hourly aggregates only — never raw HR/ECG/GPS streams.

## Identifiers and units

| Canonical ID | Category | Unit | Aggregation | Default consent tier |
|--------------|----------|------|-------------|----------------------|
| `steps` | activity | count | total | 1 — activity+sleep |
| `distance_walking_running` | activity | m | total | 1 |
| `active_energy` | activity | kcal | total | 1 |
| `basal_energy` | activity | kcal | total | 1 |
| `exercise_minutes` | activity | min | total | 1 |
| `stand_minutes` | activity | min | total | 1 |
| `flights_climbed` | activity | count | total | 1 |
| `workout_count` | workouts | count | total | 1 |
| `workout_duration` | workouts | min | total | 1 |
| `heart_rate` | cardiovascular | bpm | avg/min/max/latest | 2 — heart |
| `resting_heart_rate` | cardiovascular | bpm | avg/latest | 2 |
| `walking_heart_rate_avg` | cardiovascular | bpm | avg | 2 |
| `hrv_sdnn` | cardiovascular | ms | avg | 2 (iOS) |
| `hrv_rmssd` | cardiovascular | ms | avg | 2 (Android) |
| `respiratory_rate` | respiratory | breaths/min | avg/min/max | 3 |
| `oxygen_saturation` | respiratory | % | avg/min/max/latest | 3 |
| `sleep_total` | sleep | min | total | 1 |
| `sleep_in_bed` | sleep | min | total | 1 |
| `sleep_awake` | sleep | min | total | 1 |
| `sleep_core_light` | sleep | min | total | 1 |
| `sleep_deep` | sleep | min | total | 1 |
| `sleep_rem` | sleep | min | total | 1 |
| `body_temperature` | temperature | °C | avg/latest | 3 |
| `wrist_temperature` | temperature | °C | avg/latest + baseline delta | 3 |
| `vo2_max` | fitness | mL/kg/min | latest | 2 |
| `mindfulness_minutes` | fitness | min | total | 2 |
| `weight` | body (opt-in) | kg | latest | 4 — extended |
| `height` | body (opt-in) | cm | latest | 4 |
| `body_fat` | body (opt-in) | % | latest | 4 |
| `blood_pressure_systolic` | sensitive opt-in | mmHg | avg | 4 (off by default) |
| `blood_pressure_diastolic` | sensitive opt-in | mmHg | avg | 4 (off by default) |
| `blood_glucose` | sensitive opt-in | mg/dL | avg | 4 (off by default) |

## Semantic rules

1. Do **not** merge `hrv_sdnn` and `hrv_rmssd` without method labels.
2. Do **not** merge `body_temperature` and `wrist_temperature`.
3. Missing ≠ 0. Use `null` / quality_state.
4. Quality states: `ok`, `partial`, `no_records`, `permission_unknown`, `permission_denied`, `source_unavailable`, `stale`, `sync_error`, `unsupported`.
5. Sensitive metrics (BP, glucose) never enter risk score without separate product/legal review.
