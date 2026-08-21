# HiAir 1.1 Forecast Truth — Code Audit

Date: 2026-08-21
Branch: `feat/hiair-1.1-forecast-truth`
Baseline: `21610011` (prompt-only) on the iOS 1.0 / build-188 release line.

This audit describes **pre-implementation production code**. Implementation status lives in `docs/audit/HIAIR_1_1_FORECAST_TRUTH_QA.md`. Code + API contracts beat older docs.

---

## 1. Verdict of the current state

Day planning and safe windows in production are **not forecast-truthful**.

They project a single current environmental snapshot 24 hours forward with deterministic sine/daytime curves. Current UV, PM10, and wind are **not** provider fields: they are inferred from temperature, PM2.5, and humidity. Live current temperature / humidity / AQI / PM2.5 / ozone from Open-Meteo (default) are real.

---

## 2. Synthetic / heuristic production paths

### 2.1 `_project_environment` — sinusoidal future weather/air

File: `backend/app/services/air_risk_engine.py`

Used by:

- `_build_safe_windows` (current-risk `safeWindows` and planner windows)
- `build_day_plan` (`GET /api/air/day-plan` hourly risk)

Algorithm (UTC clock, not location timezone):

- `hour_in_day = (utcnow.hour + offset) % 24`
- `heat_wave = max(0, sin((hour-7)/24 * 2π))`
- `traffic_wave = max(0, sin((hour-5)/24 * 2π))`
- temperature `+ heat_wave*6 - 2`
- humidity clamped after `- heat_wave*8 + 3`
- AQI `+ traffic_wave*30 - 12`
- PM2.5 `+ traffic_wave*12 - 5`
- PM10 `+ traffic_wave*15 - 6`
- ozone `+ heat_wave*18 - 7`
- UV `+ heat_wave*3 - 1.5`
- wind `+ cos(offset/3)*1.2`

Timestamps are `utcnow + offset` labeled with the profile timezone string, without converting into that zone.

### 2.2 `_shift_env` — daytime curve on `/api/planner/daily`

File: `backend/app/api/planner.py`

- `daytime_factor = max(0, 6 - abs(12 - ((utcnow.hour + offset) % 24)))`
- temperature `+ factor*0.8 - 2`
- humidity / AQI / PM2.5 / ozone similarly shifted

Premium-gated (`extended_forecast`). Same live snapshot, synthetic hours.

### 2.3 Heuristic UV / PM10 / wind / feels-like

`backend/app/services/air_environment_service.py` `_snapshot_to_environmental`:

- `pm10 = pm25 * 1.45`
- `uv = max(0, (temperature_c - 16) / 2.5)`
- `wind_speed = max(0.2, 1.0 + humidity_percent/100 * 2.8)`
- `feels_like = temperature + max(0, humidity-40)*0.05`

`backend/app/services/air_score.py` `to_air_environment` (dashboard + `/planner/daily`):

- `pm10 = max(1, pm25 * 1.4)`
- `uv = 4.0` (constant)
- `wind_speed = 2.0` (constant)
- `feels_like = temperature + humidity/20`
- `timezone = "UTC"` always

### 2.4 Sample / mock current fallback (already honesty-gated)

`resolve_environment_snapshot`: cache → live → sample.

Protected env (`APP_ENV` production/staging) defaults `ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=false`. Cached `sample`/`mock` rows are not relabeled as `cached`. This must stay.

Sample fallback is **current snapshot only**. There is no hourly sample forecast today; planner invents hours from whatever current snapshot it got (including sample in dev).

---

## 3. Provider stack (actual capabilities)

Settings (`backend/app/core/settings.py`):

- `WEATHER_API_PROVIDER` default `openmeteo`
- `AQI_API_PROVIDER` default `openmeteo`
- Optional `openweathermap` + `WEATHER_API_KEY`
- Optional `waqi` + `AQI_API_KEY`

`backend/app/services/environment_service.py` **current only**:

| Provider | Fields actually fetched | Missing (then fabricated downstream) |
|---|---|---|
| Open-Meteo weather | `temperature_2m`, `relative_humidity_2m` | UV, wind, apparent temperature, dew point |
| Open-Meteo air | `us_aqi`, `pm2_5`, `ozone` | PM10, NO2 |
| OpenWeather current | `main.temp`, `main.humidity` | UV, wind unused even though API has `wind.speed` |
| WAQI | `aqi`, `iaqi.pm25`, `iaqi.o3` | PM10 unused even if `iaqi.pm10` exists |

**No production hourly forecast HTTP call exists.** Open-Meteo can supply 48h weather + air-quality hourly (including UV, wind, PM10) without an API key. That is the 1.1 default path.

If a configured provider cannot supply real hourly data, 1.1 must return partial/unavailable — not interpolate 3-hour OpenWeather slots into fake hourly points.

---

## 4. Cache

- Geo key: `round(lat,2):round(lon,2)` in `air_repository._geo_hash`
- TTL: `ENVIRONMENT_CACHE_TTL_SECONDS` default 900
- Table `environment_snapshots` already has nullable `feels_like`, `pm10`, `uv`, `wind_speed` (`003_ai_mvp_architecture.sql`)
- `save_environment_snapshot` writes those columns
- `get_latest_environment_snapshot` **does not read them back**; cache replay re-runs the heuristics

No in-memory hourly forecast cache.

---

## 5. API contracts in use by mobile

Mobile iOS/Android planner uses **`GET /api/air/day-plan?profileId=`** (not `/api/planner/daily`).

| Endpoint | Gate | Today |
|---|---|---|
| `GET /api/air/current-risk` | auth | live/cached/sample current + synthetic `safeWindows` |
| `GET /api/air/day-plan` | auth + Premium `extended_forecast` | 24 synthetic `hourlyRisk` + synthetic windows |
| `GET /api/planner/daily` | auth + Premium | 6–24 synthetic hours, different shape |
| `GET /api/dashboard/overview` | auth | current snapshot only; risk via `to_air_environment` heuristics |
| `GET /api/air/recommendations` | auth | current snapshot + synthetic windows inside risk |

Existing `DayPlanResponse` fields: `profileId`, `timezone`, `hourlyRisk[{hour,overallRisk}]`, `safeWindows`, `ventilationWindows`.

iOS `AirDayPlanResponse` / `AirEnvironmentalInput` use required `Double` for `pm10`/`uv`/`windSpeed`. Additive JSON keys are ignored by Codable. **Nulling required 1.0 numeric fields would break 1.0 clients.** 1.1 clients must decode those fields as optional. Default production Open-Meteo can supply real numbers so 1.0 keeps working on the default stack.

---

## 6. Timezone

- Profile has `timezone` (IANA), default `UTC`
- Planner timestamps are UTC wall-clock arithmetic
- iOS `HiAirHumanDate.timeRange(fromISO:)` formats with **device** timezone, not forecast timezone
- Dashboard hourly chart uses `item.hour.prefix(2)` which is the year `"20"` for ISO dates — display bug, not a redesign

1.1 must emit offset-aware ISO-8601 plus timezone id from the provider/location zone, and format windows in that zone.

---

## 7. What is already truthful

- Open-Meteo (or configured) **current** temperature, humidity, AQI, PM2.5, ozone
- Production fail-closed sample rules
- Premium gate on planner
- Risk thresholds themselves (heat/AQI/PM scoring) — they are applied to fake future inputs
- HealthKit / personal load on **current** risk
- Auth, subscriptions fail-closed verifiers

---

## 8. Call graph to change (no behavior change in commit 1)

```
GET /api/air/day-plan
  → load_environment (heuristics)
  → build_day_plan → _project_environment × 24

GET /api/air/current-risk
  → load_environment
  → evaluate_risk → _build_safe_windows → _project_environment × 24

GET /api/planner/daily
  → resolve_environment_snapshot
  → _shift_env × N
  → to_air_environment (constants)

GET /api/dashboard/overview
  → resolve_environment_snapshot
  → to_air_environment
  → evaluate_risk (synthetic windows)

briefing_service.compose_briefing
  → build_day_plan (synthetic)
```

Personal load must stay **current/latest** for every hourly evaluation (do not invent future physiology).
