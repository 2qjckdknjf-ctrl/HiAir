from app.models.risk import RiskEstimateResponse


def should_notify(risk: RiskEstimateResponse) -> bool:
    return risk.level in ("high", "very_high")


def build_notification_text(risk: RiskEstimateResponse) -> str:
    if risk.level == "very_high":
        return "Very high air/heat risk now. Reduce outdoor exposure."
    if risk.level == "high":
        return "High air/heat risk now. Limit outdoor activity."
    if risk.level == "medium":
        return "Moderate risk conditions. Plan safer time windows."
    return "Low risk conditions. Keep regular precautions."
