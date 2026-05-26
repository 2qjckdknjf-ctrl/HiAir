from app.services.risk_level_contract import normalize_air_level_value, normalize_legacy_level


def test_normalize_legacy_level_maps_medium_to_moderate() -> None:
    assert normalize_legacy_level("medium") == "moderate"
    assert normalize_legacy_level("HIGH") == "high"


def test_normalize_air_level_value_maps_medium_to_moderate() -> None:
    assert normalize_air_level_value("medium") == "moderate"
    assert normalize_air_level_value("MODERATE") == "moderate"
