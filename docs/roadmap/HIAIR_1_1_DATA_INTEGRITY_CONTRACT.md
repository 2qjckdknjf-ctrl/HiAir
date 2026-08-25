# HiAir 1.1 — Data Integrity Contract

This is the old vs new contract for Forecast Truth. Additive fields only on existing mobile endpoints. Do not require a 1.0 client migration for the default Open-Meteo stack.

---

## Integrity rules (release blockers)

1. No synthetic future forecast in production (`_project_environment`, `_shift_env`, sine/traffic curves).
2. No fake current data in protected environments (existing sample fail-closed stays).
3. A metric is never presented as measured/forecast if it was inferred from an unrelated field.
4. Every forecast point has provenance + timestamp.
5. Missing provider data is `null` / listed in `missingMetrics`. `derived` is only for an explicitly modeled method with tests — not a disguise.
6. LLM explains risk; it does not calculate forecast safety.
7. HealthKit remains optional, consent-bound, wellness-only.
8. Store verification remains fail-closed.

---

## Canonical kinds

`observed` | `forecast` | `derived` | `cached`

Freshness: `live` | `cached` | `stale`

Quality: `complete` | `partial` | `unavailable`

---

## Provider field matrix (1.1)

Default: Open-Meteo weather + Open-Meteo air quality, `timezone=auto`, wind in m/s, ozone µg/m³, AQI = US AQI.

| Field | Open-Meteo weather | Open-Meteo air | OpenWeather current | WAQI current |
|---|---|---|---|---|
| temperature_c | hourly + current | — | current | — |
| apparent_temperature_c | hourly + current | — | — | — |
| relative_humidity_pct | hourly + current | — | current | — |
| dew_point_c | hourly + current | — | — | — |
| wind_speed_mps | hourly + current | — | current `wind.speed` | iaqi.w if present |
| wind_gust_mps | hourly + current | — | — | — |
| uv_index | hourly + current | — | not fetched (no silent temp inference) | — |
| aqi | — | `us_aqi` hourly + current | — | `aqi` |
| pm25_ugm3 | — | `pm2_5` | — | iaqi.pm25 |
| pm10_ugm3 | — | `pm10` | — | iaqi.pm10 if present |
| ozone_ugm3 | — | `ozone` | — | iaqi.o3 |
| no2_ugm3 | — | `nitrogen_dioxide` | — | iaqi.no2 if present |

If hourly is missing from the configured provider: planner returns `dataQuality=unavailable` or `partial`, empty `hourlyRisk`, empty safe windows. Current-risk may still succeed from current data.

OpenWeather 5-day/3-hour is **not** an hourly forecast. Do not interpolate it.

---

## Existing endpoints (preserve)

### `GET /api/air/current-risk?profileId=`

Unchanged required fields. Additive optional:

- `environmental.missingMetrics: string[]`
- `dataQuality`, `freshness`, `sources`, `generatedAt`, `timezone`
- `risk.safeWindows` built from real hourly points when forecast exists; otherwise `[]` (honest, not synthetic)

`environmental.uv` / `pm10` / `wind_speed`: provider value when present. 1.1 iOS/Android decode as optional. Default Open-Meteo sends real numbers (1.0 clients keep working).

### `GET /api/air/day-plan?profileId=`

Premium `extended_forecast` unchanged.

Existing: `profileId`, `timezone`, `hourlyRisk`, `safeWindows`, `ventilationWindows`.

Additive optional:

```json
{
  "generatedAt": "2026-08-21T12:00:00+02:00",
  "dataQuality": "complete",
  "freshness": "live",
  "sources": ["openmeteo_weather", "openmeteo_air"],
  "forecastHours": 48,
  "forecastAvailable": true,
  "missingMetrics": []
}
```

`hourlyRisk[].hour` is ISO-8601 with offset in the **location** timezone. Minimum 24h, target 48h, chronological.

Safe window `start`/`end` are hour-grid bounds from those same timestamps. Confidence reflects completeness/freshness. No minute-level precision claim.

### `GET /api/planner/daily`

Keep Premium gate and response shape (`hourly[]`, `safe_windows`). Hours must come from the same real forecast, not `_shift_env`. Additive metadata allowed.

### `GET /api/dashboard/overview`

Current snapshot only. Pass through real UV/PM10/wind when present. No hourly synthesis. Additive optional snapshot fields allowed.

---

## Optional new endpoint (not required for mobile)

`GET /api/air/forecast?profileId=&hours=48` may be added additively. Mobile 1.1 continues to use `day-plan` / `current-risk`.

---

## Cache

- Geo-keyed (`round(lat,2):round(lon,2)`), TTL = existing `ENVIRONMENT_CACHE_TTL_SECONDS` (900s)
- Forecast cache may be in-memory (no new database)
- Cached responses labeled `freshness=cached`
- If live fails and cache age ≤ 2h: serve `stale` (visible), never sample forecast in production
- Older than 2h: unavailable

---

## Personal load

Hourly risk uses the **current** validated personal-load context for every hour. Future physiology is not extrapolated.

---

## Compatibility

| Change | 1.0 client |
|---|---|
| Extra day-plan keys | Ignored (Codable / JSONObject) |
| Real UV/PM10/wind numbers instead of heuristics | Safer numbers, same types |
| Empty hourlyRisk when forecast unavailable | Existing empty/error UI |
| `null` UV on non-Open-Meteo providers | 1.0 may fail decode; 1.1 optional decode. Default prod provider supplies numbers. |

---

## Forbidden in production

- `_project_environment` / `_shift_env` on planner or safe-window paths
- `pm10 = pm25 * k`
- UV from temperature
- Wind from humidity
- Constant UV=4 / wind=2
- Sample/mock hourly forecast in protected env
- LLM-invented windows
