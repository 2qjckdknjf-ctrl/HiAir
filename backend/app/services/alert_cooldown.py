"""Per-alert-type delivery cooldown minutes for HiAir 1.4."""

from __future__ import annotations

from app.models.air import AlertType

DEFAULT_ALERT_COOLDOWN_MINUTES = 60

ALERT_COOLDOWN_MINUTES_BY_TYPE: dict[str, int] = {
    AlertType.RISK_INCREASE.value: 45,
    AlertType.CAUTION_FOR_PROFILE.value: 90,
    AlertType.SAFE_WINDOW_OPEN.value: 180,
    AlertType.VENTILATION_WINDOW_OPEN.value: 180,
    AlertType.EVENING_SUMMARY.value: 720,
    AlertType.NEXT_DAY_WARNING.value: 360,
    # External decision-gate candidates (smoke / integrations)
    "air_worsening": 60,
}


def cooldown_minutes_for_alert_type(alert_type: str) -> int:
    return ALERT_COOLDOWN_MINUTES_BY_TYPE.get(alert_type, DEFAULT_ALERT_COOLDOWN_MINUTES)
