from __future__ import annotations

from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import app.services.air_environment_service as air_environment_service
import app.services.air_recommendation_engine as air_recommendation_engine
import app.services.air_repository as air_repository
import app.services.air_risk_engine as air_risk_engine
import app.services.ai_explanation_service as ai_explanation_service
import app.services.briefing_repository as briefing_repository
import app.services.notification_dispatcher as notification_dispatcher
import app.services.notification_repository as notification_repository
import app.services.settings_repository as settings_repository
from app.services.risk_level_contract import normalize_air_risk, normalize_day_plan


def get_due_briefings(now_utc: datetime | None = None) -> list[dict[str, str]]:
    now = now_utc or datetime.now(UTC)
    due: list[dict[str, str]] = []
    for item in briefing_repository.list_enabled_schedules():
        timezone_name = str(item["timezone"] or "UTC")
        local_time = str(item["local_time"] or "07:30")
        user_id = str(item["user_id"])
        if not _is_due(now_utc=now, local_time=local_time, timezone_name=timezone_name, last_sent_at=item["last_sent_at"]):
            continue
        due.append({"user_id": user_id, "timezone": timezone_name, "local_time": local_time})
    return due


def compose_briefing(user_id: str) -> tuple[str, str | None, str]:
    profiles = briefing_repository.get_user_profile_ids(user_id)
    if not profiles:
        return "HiAir morning briefing: profile is missing.", None, "no_profile"

    profile_id = profiles[0]
    profile = air_repository.get_profile_context(profile_id)
    if profile is None:
        return "HiAir morning briefing: profile is missing.", None, "no_profile_context"

    user_settings = settings_repository.get_user_settings(user_id)
    environment = air_environment_service.load_environment(profile, force_live=False)
    risk = normalize_air_risk(air_risk_engine.evaluate_risk(profile, environment))
    plan = normalize_day_plan(air_risk_engine.build_day_plan(profile, environment))
    recommendation = air_recommendation_engine.generate_recommendation(profile, risk, language=user_settings.preferred_language)
    explanation, _ = ai_explanation_service.generate_explanation(
        profile=profile,
        risk=risk,
        recommendation=recommendation,
        language=user_settings.preferred_language,
        risk_assessment_id=None,
    )
    first_window = plan.safeWindows[0] if plan.safeWindows else None
    window_text = f"{first_window.start}-{first_window.end}" if first_window else "later tonight"
    message = (
        f"Good morning. Today's risk is {risk.overallRisk.value}. "
        f"Best outdoor window: {window_text}. {explanation}"
    )
    return message, profile_id, risk.overallRisk.value


def dispatch_due_briefings(now_utc: datetime | None = None, dry_run: bool = False) -> list[dict[str, str | int | bool]]:
    results: list[dict[str, str | int | bool]] = []
    for due in get_due_briefings(now_utc=now_utc):
        user_id = str(due["user_id"])
        message, profile_id, risk_level = compose_briefing(user_id)
        targets = notification_repository.list_active_device_targets(user_id=user_id)
        if dry_run:
            results.append(
                {
                    "user_id": user_id,
                    "profile_id": profile_id or "",
                    "risk_level": risk_level,
                    "dispatched": 0,
                    "skipped": False,
                    "reason": "dry_run",
                }
            )
            continue
        dispatched, skipped, reason, _, _ = notification_dispatcher.dispatch_stub(
            user_id=user_id,
            profile_id=profile_id,
            risk_level=risk_level,
            message=message,
            device_targets=targets,
            force_send=True,
        )
        briefing_repository.mark_sent(user_id=user_id)
        results.append(
            {
                "user_id": user_id,
                "profile_id": profile_id or "",
                "risk_level": risk_level,
                "dispatched": dispatched,
                "skipped": skipped,
                "reason": reason,
            }
        )
    return results


def _is_due(now_utc: datetime, local_time: str, timezone_name: str, last_sent_at: str | None) -> bool:
    try:
        tz = ZoneInfo(timezone_name)
    except Exception:
        tz = ZoneInfo("UTC")
    local_now = now_utc.astimezone(tz)
    expected_hour, expected_minute = _parse_local_time(local_time)
    target_local = local_now.replace(hour=expected_hour, minute=expected_minute, second=0, microsecond=0)
    minutes_since_target = (local_now - target_local).total_seconds() / 60.0
    within_window = 0.0 <= minutes_since_target < 5.0
    if not within_window:
        return False
    if not last_sent_at:
        return True
    try:
        last_sent = datetime.fromisoformat(last_sent_at.replace("Z", "+00:00"))
    except Exception:
        return True
    return now_utc - last_sent.astimezone(UTC) >= timedelta(hours=18)


def _parse_local_time(value: str) -> tuple[int, int]:
    try:
        hour_str, minute_str = value.split(":")
        return int(hour_str), int(minute_str)
    except Exception:
        return 7, 30
