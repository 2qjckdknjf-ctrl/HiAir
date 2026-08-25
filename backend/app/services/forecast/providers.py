"""Forecast provider protocols. Adapters normalize units and provenance; they never compute risk."""

from typing import Protocol

from app.models.forecast import EnvironmentalForecastPoint


class WeatherForecastProvider(Protocol):
    name: str

    def get_current(self, lat: float, lon: float) -> EnvironmentalForecastPoint:
        """Return the current weather point. Missing metrics stay null."""

    def get_hourly(self, lat: float, lon: float, hours: int = 48) -> list[EnvironmentalForecastPoint]:
        """Return real hourly weather points. Empty if the provider has no hourly feed."""


class AirQualityForecastProvider(Protocol):
    name: str

    def get_current(self, lat: float, lon: float) -> EnvironmentalForecastPoint:
        """Return the current air-quality point. Missing metrics stay null."""

    def get_hourly(self, lat: float, lon: float, hours: int = 48) -> list[EnvironmentalForecastPoint]:
        """Return real hourly air-quality points. Empty if the provider has no hourly feed."""
