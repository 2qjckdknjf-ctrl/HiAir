from __future__ import annotations

from app.models.forecast import EnvironmentalForecast, EnvironmentalForecastPoint, ForecastQuality

CORE_PLANNER_METRICS = (
    "temperature_c",
    "relative_humidity_pct",
    "aqi",
    "pm25_ugm3",
)


def point_missing_core(point: EnvironmentalForecastPoint) -> list[str]:
    missing: list[str] = []
    for name in CORE_PLANNER_METRICS:
        if getattr(point, name, None) is None:
            missing.append(name)
    return missing


def classify_forecast(hourly: list[EnvironmentalForecastPoint]) -> tuple[ForecastQuality, list[str]]:
    if not hourly:
        return ForecastQuality.UNAVAILABLE, list(CORE_PLANNER_METRICS)
    missing: set[str] = set()
    for point in hourly:
        missing.update(point_missing_core(point))
        missing.update(point.missing_metrics)
    core_missing = [name for name in CORE_PLANNER_METRICS if name in missing]
    extra = sorted(name for name in missing if name not in CORE_PLANNER_METRICS)
    if core_missing:
        return ForecastQuality.PARTIAL, sorted(set(core_missing + extra))
    return ForecastQuality.COMPLETE, extra


def summarize_forecast(forecast: EnvironmentalForecast) -> str:
    hours = len(forecast.hourly)
    sources = ",".join(forecast.sources) if forecast.sources else "none"
    return f"{forecast.quality.value}:{forecast.freshness.value}:{hours}h:{sources}"
