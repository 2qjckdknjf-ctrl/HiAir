"""Family member risk must not inherit caregiver wearable load."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from app.models.air import ProfileType, RiskLevel, UserProfileContext
from app.services.family_risk_service import _assess_member_risk


def test_member_risk_passes_none_personal_load() -> None:
    link = MagicMock(
        id="l1",
        memberProfileId="child-1",
        relation="child",
        label="Kid",
    )
    profile = UserProfileContext(
        profile_id="child-1",
        user_id="owner-1",
        profile_type=ProfileType.CHILD,
        home_lat=55.75,
        home_lon=37.62,
        timezone="Europe/Moscow",
        location_name="Moscow",
    )
    with patch(
        "app.services.family_risk_service.air_repository.get_profile_context",
        return_value=profile,
    ):
        with patch(
            "app.services.family_risk_service.air_environment_service.load_environment",
            return_value=MagicMock(),
        ):
            with patch(
                "app.services.family_risk_service._load_forecast_or_none",
                return_value=None,
            ):
                with patch(
                    "app.services.family_risk_service.overlay_forecast_current",
                    side_effect=lambda env, forecast: env,
                ):
                    with patch(
                        "app.services.family_risk_service.forecast_to_hourly_inputs",
                        return_value=[],
                    ):
                        with patch(
                            "app.services.family_risk_service.air_risk_engine.evaluate_risk",
                        ) as evaluate:
                            evaluate.return_value = MagicMock(overallRisk=RiskLevel.LOW)
                            line = _assess_member_risk(owner_user_id="owner-1", link=link)

    assert line.available is True
    assert evaluate.call_args.args[2] is None
