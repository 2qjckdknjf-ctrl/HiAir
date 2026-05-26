from app.models.risk import RiskEstimateResponse
from app.services.risk_level_contract import normalize_legacy_level


def should_notify(risk: RiskEstimateResponse) -> bool:
    return risk.level in ("high", "very_high")


def build_notification_text(risk: RiskEstimateResponse) -> str:
    level = normalize_legacy_level(risk.level)
    if level == "very_high":
        return "Very high air/heat risk now. Reduce outdoor exposure."
    if level == "high":
        return "High air/heat risk now. Limit outdoor activity."
    if level == "moderate":
        return "Moderate risk conditions. Plan safer time windows."
    return "Low risk conditions. Keep regular precautions."
