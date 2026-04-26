from app.models.risk import RiskEstimateResponse
from app.services.localization import normalize_language, t


def should_notify(risk: RiskEstimateResponse) -> bool:
    return risk.level in ("high", "very_high")


def build_notification_text(risk: RiskEstimateResponse, language: str = "ru") -> str:
    lang = normalize_language(language)
    if risk.level == "very_high":
        return t(lang, "notification.very_high")
    if risk.level == "high":
        return t(lang, "notification.high")
    if risk.level in ("medium", "moderate"):
        return t(lang, "notification.medium")
    return t(lang, "notification.low")
