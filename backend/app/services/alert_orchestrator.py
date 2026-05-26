from datetime import datetime, timezone

from app.models.air import (
    AlertDecision,
    AlertSeverity,
    AlertType,
    RecommendationCard,
    RiskAssessmentResult,
    UserProfileContext,
)
from app.services.localization import normalize_language, t
from app.services.risk_level_contract import normalize_air_level_value
import app.services.air_repository as air_repository
import app.services.settings_repository as settings_repository


def _severity_from_risk_level(level: str) -> AlertSeverity:
    if level == "very_high":
        return AlertSeverity.CRITICAL_NON_MEDICAL
    if level == "high":
        return AlertSeverity.HIGH
    if level == "moderate":
        return AlertSeverity.MEDIUM
    return AlertSeverity.LOW


def _is_quiet_hours(start_hour: int, end_hour: int, now_hour: int) -> bool:
    if start_hour == end_hour:
        return False
    if start_hour < end_hour:
        return start_hour <= now_hour < end_hour
    return now_hour >= start_hour or now_hour < end_hour


def evaluate_alert(
    profile: UserProfileContext,
    risk: RiskAssessmentResult,
    recommendation: RecommendationCard,
    language: str = "ru",
) -> AlertDecision:
    lang = normalize_language(language)
    user_settings = settings_repository.get_user_settings(profile.user_id)
    now_hour = datetime.now(timezone.utc).hour
    if not user_settings.push_alerts_enabled:
        return AlertDecision(
            shouldSend=False,
            alertType=None,
            severity=None,
            title=t(lang, "alert.disabled.title"),
            body=t(lang, "alert.disabled.body"),
            dedupeKey=f"{profile.profile_id}:disabled",
            reason="alerts_disabled",
        )
    if _is_quiet_hours(user_settings.quiet_hours_start, user_settings.quiet_hours_end, now_hour):
        return AlertDecision(
            shouldSend=False,
            alertType=None,
            severity=None,
            title=t(lang, "alert.quiet.title"),
            body=t(lang, "alert.quiet.body"),
            dedupeKey=f"{profile.profile_id}:quiet_hours",
            reason="quiet_hours",
        )

    latest = air_repository.get_latest_risk_assessment(profile.profile_id)
    latest_level = normalize_air_level_value(latest["overall_risk"]) if latest else "low"
    current_level = normalize_air_level_value(risk.overallRisk.value)
    alert_type = AlertType.RISK_INCREASE if current_level != latest_level else AlertType.CAUTION_FOR_PROFILE
    severity = _severity_from_risk_level(current_level)

    if current_level == latest_level and current_level in ("low", "moderate"):
        return AlertDecision(
            shouldSend=False,
            alertType=None,
            severity=None,
            title=t(lang, "alert.nochange.title"),
            body=t(lang, "alert.nochange.body"),
            dedupeKey=f"{profile.profile_id}:{current_level}:stable",
            reason="no_material_change",
        )

    dedupe_key = f"{profile.profile_id}:{alert_type.value}:{severity.value}:{current_level}"
    if air_repository.find_recent_alert_by_dedupe_key(dedupe_key, within_hours=4):
        return AlertDecision(
            shouldSend=False,
            alertType=None,
            severity=None,
            title=t(lang, "alert.duplicate.title"),
            body=t(lang, "alert.duplicate.body"),
            dedupeKey=dedupe_key,
            reason="deduplicated",
        )

    title = recommendation.headline
    body = recommendation.summary
    return AlertDecision(
        shouldSend=True,
        alertType=alert_type,
        severity=severity,
        title=title,
        body=body,
        dedupeKey=dedupe_key,
        reason="risk_rules_triggered",
    )
