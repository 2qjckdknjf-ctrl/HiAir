"""Tests for per-alert-type cooldown configuration."""

from app.models.air import AlertType
from app.services.alert_cooldown import (
    DEFAULT_ALERT_COOLDOWN_MINUTES,
    cooldown_minutes_for_alert_type,
)


def test_risk_increase_has_shorter_cooldown_than_caution() -> None:
    risk = cooldown_minutes_for_alert_type(AlertType.RISK_INCREASE.value)
    caution = cooldown_minutes_for_alert_type(AlertType.CAUTION_FOR_PROFILE.value)
    assert risk < caution
    assert risk == 45
    assert caution == 90


def test_unknown_alert_type_uses_default() -> None:
    assert cooldown_minutes_for_alert_type("custom_integration_alert") == DEFAULT_ALERT_COOLDOWN_MINUTES
