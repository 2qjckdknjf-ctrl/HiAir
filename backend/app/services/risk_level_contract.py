from app.services.observability import record_risk_level_alias


def normalize_legacy_level(level: str) -> str:
    normalized = level.strip().lower()
    if normalized == "moderate":
        record_risk_level_alias(domain="legacy", source_level="moderate", normalized_level="medium")
        return "medium"
    return normalized


def normalize_air_level_value(level: str) -> str:
    normalized = level.strip().lower()
    if normalized == "medium":
        record_risk_level_alias(domain="air", source_level="medium", normalized_level="moderate")
        return "moderate"
    return normalized
