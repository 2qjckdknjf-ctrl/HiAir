"""HiAir 1.6 — map personal baseline strain into alert sensitivity.

Wellness-only: when wearable baselines show recovery strain, make the user's
alert threshold one step more sensitive. Never invents metrics; no-op when
baselines are unavailable.
"""

from __future__ import annotations

from app.services.personal_load_engine import PersonalLoadResult

# Reason codes that prove a *personal baseline* comparison was available.
BASELINE_STRAIN_REASON_CODES = frozenset(
    {
        "resting_hr_above_7d_baseline",
        "resting_hr_above_30d_baseline",
        "hrv_below_7d_baseline",
        "sleep_below_7d_baseline",
    }
)

# Matches user settings alert_threshold values (medium|high|very_high).
_THRESHOLD_ORDER = ("medium", "high", "very_high")


def more_sensitive_alert_threshold(alert_threshold: str) -> str:
    """Lower alert threshold by one step (very_high → high → medium)."""
    normalized = alert_threshold.strip().lower()
    if normalized == "moderate":
        normalized = "medium"
    if normalized not in _THRESHOLD_ORDER:
        return "high"
    index = _THRESHOLD_ORDER.index(normalized)
    return _THRESHOLD_ORDER[max(0, index - 1)]


def effective_alert_threshold(
    alert_threshold: str,
    personal_load: PersonalLoadResult | None,
) -> tuple[str, list[str]]:
    """Return (threshold, reason_codes) after optional baseline-driven boost.

    Boost only when personal load score shows meaningful strain *and* at least
    one baseline-comparison reason code is present (honest: no invented baselines).
    """
    base = alert_threshold.strip().lower()
    if base == "moderate":
        base = "medium"
    if base not in _THRESHOLD_ORDER:
        base = "high"

    if personal_load is None or personal_load.score < 15:
        return base, []

    strain_codes = [
        code for code in personal_load.reason_codes if code in BASELINE_STRAIN_REASON_CODES
    ]
    if not strain_codes:
        return base, []

    boosted = more_sensitive_alert_threshold(base)
    reasons = ["alert_threshold_boosted_from_baselines", *sorted(set(strain_codes))]
    return boosted, reasons
