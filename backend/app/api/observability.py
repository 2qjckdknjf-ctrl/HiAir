from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import require_ops_admin_token
from app.core.settings import settings
from app.services.ai_observability_repository import ai_event_breakdown, ai_event_summary, ai_event_trend
from app.services.observability import snapshot_metrics

router = APIRouter(prefix="/observability", tags=["observability"])


def _provider_metadata() -> dict[str, object]:
    configured = bool(settings.openai_api_key.strip())
    return {
        "provider_configured": configured,
        "provider_name": "openai" if configured else "none",
        "configured_model": settings.openai_model,
        "configured_prompt_version": settings.openai_prompt_version,
        "runtime_mode": "live_llm" if configured else "template_fallback_only",
    }


@router.get("/metrics")
def metrics(_authorized: bool = Depends(require_ops_admin_token)) -> dict[str, object]:
    return snapshot_metrics()


@router.get("/ai-summary")
def ai_summary(
    hours: int = Query(default=24, ge=1, le=168),
    _authorized: bool = Depends(require_ops_admin_token),
) -> dict[str, object]:
    try:
        summary = ai_event_summary(hours=hours)
        total = max(1, summary["total"])
        return {
            **summary,
            "hours": hours,
            **_provider_metadata(),
            "fallback_rate_pct": round(summary["fallback_count"] / total * 100, 2),
            "guardrail_block_rate_pct": round(summary["guardrail_block_count"] / total * 100, 2),
            "timeout_rate_pct": round(summary["timeout_count"] / total * 100, 2),
            "network_rate_pct": round(summary["network_count"] / total * 100, 2),
            "server_rate_pct": round(summary["server_count"] / total * 100, 2),
        }
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("/ai-summary-detailed")
def ai_summary_detailed(
    hours: int = Query(default=24, ge=1, le=168),
    _authorized: bool = Depends(require_ops_admin_token),
) -> dict[str, object]:
    try:
        summary = ai_event_summary(hours=hours)
        trend = ai_event_trend(hours=hours)
        breakdown = ai_event_breakdown(hours=hours)
        total = max(1, summary["total"])
        return {
            "summary": {
                **summary,
                "hours": hours,
                **_provider_metadata(),
                "fallback_rate_pct": round(summary["fallback_count"] / total * 100, 2),
                "guardrail_block_rate_pct": round(summary["guardrail_block_count"] / total * 100, 2),
                "timeout_rate_pct": round(summary["timeout_count"] / total * 100, 2),
                "network_rate_pct": round(summary["network_count"] / total * 100, 2),
                "server_rate_pct": round(summary["server_count"] / total * 100, 2),
            },
            "trend": trend,
            "breakdown": breakdown,
            "provider": _provider_metadata(),
        }
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
