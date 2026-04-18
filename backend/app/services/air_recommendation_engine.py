from app.models.air import RecommendationCard, RiskAssessmentResult, RiskLevel, SafeWindowType, UserProfileContext
from app.services.localization import normalize_language, t


def generate_recommendation(
    profile: UserProfileContext,
    risk: RiskAssessmentResult,
    language: str = "ru",
) -> RecommendationCard:
    lang = normalize_language(language)
    headline = t(lang, "rec.low.headline")
    summary = t(lang, "rec.low.summary")
    actions: list[str] = [t(lang, "rec.low.action")]

    if risk.overallRisk in (RiskLevel.HIGH, RiskLevel.VERY_HIGH):
        headline = t(lang, "rec.high.headline")
        summary = t(lang, "rec.high.summary")
        actions = [
            t(lang, "rec.high.action1"),
            t(lang, "rec.high.action2"),
            t(lang, "rec.high.action3"),
        ]
    elif risk.overallRisk in (RiskLevel.MODERATE, RiskLevel.MEDIUM):
        headline = t(lang, "rec.moderate.headline")
        summary = t(lang, "rec.moderate.summary")
        actions = [
            t(lang, "rec.moderate.action1"),
            t(lang, "rec.moderate.action2"),
            t(lang, "rec.moderate.action3"),
        ]

    if "keep_windows_closed" in risk.recommendationFlags:
        actions.append(t(lang, "rec.windows.closed"))
    if "ventilate_later" in risk.recommendationFlags:
        ventilation = next((item for item in risk.safeWindows if item.type == SafeWindowType.VENTILATION), None)
        if ventilation:
            actions.append(t(lang, "rec.ventilate.window", start=ventilation.start[11:16], end=ventilation.end[11:16]))
        else:
            actions.append(t(lang, "rec.ventilate.later"))
    if profile.profile_type.value in ("child", "elderly"):
        actions.append(t(lang, "rec.profile.caution"))

    unique_actions = list(dict.fromkeys(actions))
    return RecommendationCard(headline=headline, summary=summary, actions=unique_actions[:3])
