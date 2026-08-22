from datetime import datetime, timezone

from app.models.air import (
    AlertDecision,
    AlertSeverity,
    AlertType,
    RecommendationCard,
    RiskAssessmentResult,
    UserProfileContext,
)
from app.models.alert_decision import (
    AlertCandidate,
    AlertDecisionReason as DecisionReason,
)
from app.services.localization import normalize_language, t
from app.services.risk_level_contract import normalize_air_level_value
import app.services.air_repository as air_repository
import app.services.alert_decision_engine as alert_decision_engine
import app.services.observability as observability
import app.services.settings_repository as settings_repository

ALERT_COOLDOWN_MINUTES = 60


def _severity_from_risk_level(level: str) -> AlertSeverity:
    if level == "very_high":
        return AlertSeverity.CRITICAL_NON_MEDICAL
    if level == "high":
        return AlertSeverity.HIGH
    if level == "moderate":
        return AlertSeverity.MEDIUM
    return AlertSeverity.LOW


_THRESHOLD_MIN_ORDER = {
    "medium": 1,
    "high": 2,
    "very_high": 3,
}


def _personal_threshold_met(alert_threshold: str, current_level: str) -> bool:
    threshold = normalize_air_level_value(alert_threshold)
    min_order = _THRESHOLD_MIN_ORDER.get(threshold, 2)
    level_order = {
        "low": 0,
        "moderate": 1,
        "high": 2,
        "very_high": 3,
    }.get(normalize_air_level_value(current_level), 0)
    return level_order >= min_order


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
    already_sent = None
    if air_repository.find_recent_alert_by_dedupe_key(dedupe_key, within_hours=4):
        already_sent = dedupe_key

    reason_code = (
        DecisionReason.THRESHOLD_CROSSED
        if alert_type == AlertType.RISK_INCREASE
        else DecisionReason.SIGNIFICANT_CHANGE
    )
    gate = alert_decision_engine.decide_alert(
        AlertCandidate(
            alertType=alert_type.value,
            severity=severity.value,
            reasonCode=reason_code,
            profileId=profile.profile_id,
            localHour=now_hour,
            quietHoursStart=user_settings.quiet_hours_start,
            quietHoursEnd=user_settings.quiet_hours_end,
            cooldownMinutesRemaining=air_repository.minutes_until_alert_cooldown_elapsed(
                profile.profile_id,
                cooldown_minutes=ALERT_COOLDOWN_MINUTES,
            ),
            alreadySentFingerprint=already_sent,
            fingerprint=dedupe_key,
            actionable=current_level in ("high", "very_high") or alert_type == AlertType.RISK_INCREASE,
            personalThresholdMet=_personal_threshold_met(user_settings.alert_threshold, current_level),
        )
    )
    observability.record_alert_decision(
        suppressed=not gate.shouldNotify,
        reason_codes=gate.reasonCodes if not gate.shouldNotify else None,
    )
    if not gate.shouldNotify:
        suppress_reason = gate.reasonCodes[0] if gate.reasonCodes else "suppressed"
        # Preserve legacy reason string used by clients/tests.
        if suppress_reason == "duplicate":
            suppress_reason = "deduplicated"
        title_key = "alert.quiet.title" if suppress_reason == "quiet_hours" else "alert.duplicate.title"
        body_key = "alert.quiet.body" if suppress_reason == "quiet_hours" else "alert.duplicate.body"
        if suppress_reason == "no_actionable_change":
            title_key = "alert.nochange.title"
            body_key = "alert.nochange.body"
        return AlertDecision(
            shouldSend=False,
            alertType=None,
            severity=None,
            title=t(lang, title_key),
            body=t(lang, body_key),
            dedupeKey=dedupe_key,
            reason=suppress_reason,
        )

    return AlertDecision(
        shouldSend=True,
        alertType=alert_type,
        severity=severity,
        title=recommendation.headline,
        body=recommendation.summary,
        dedupeKey=dedupe_key,
        reason="risk_rules_triggered",
    )
