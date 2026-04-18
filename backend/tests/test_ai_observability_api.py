from app.api import observability as observability_api


def test_ai_summary_rates(monkeypatch) -> None:
    monkeypatch.setattr(
        observability_api,
        "ai_event_summary",
        lambda hours: {
            "total": 10,
            "fallback_count": 3,
            "guardrail_block_count": 1,
            "timeout_count": 2,
            "network_count": 1,
            "server_count": 1,
        },
    )
    payload = observability_api.ai_summary(hours=24)
    assert payload["hours"] == 24
    assert payload["total"] == 10
    assert payload["fallback_rate_pct"] == 30.0
    assert payload["guardrail_block_rate_pct"] == 10.0
    assert payload["timeout_rate_pct"] == 20.0
    assert payload["network_rate_pct"] == 10.0
    assert payload["server_rate_pct"] == 10.0


def test_ai_summary_detailed_shape(monkeypatch) -> None:
    monkeypatch.setattr(
        observability_api,
        "ai_event_summary",
        lambda hours: {
            "total": 5,
            "fallback_count": 1,
            "guardrail_block_count": 1,
            "timeout_count": 1,
            "network_count": 1,
            "server_count": 0,
        },
    )
    monkeypatch.setattr(
        observability_api,
        "ai_event_trend",
        lambda hours: [{"hour": "2026-04-07T10:00:00Z", "total": 2, "fallback_count": 1, "guardrail_block_count": 0}],
    )
    monkeypatch.setattr(
        observability_api,
        "ai_event_breakdown",
        lambda hours: {
            "by_prompt_version": [{"prompt_version": "hiair-expl-v1", "total": 5, "fallback_count": 1, "guardrail_block_count": 1}],
            "by_model_name": [{"model_name": "gpt-4o-mini", "total": 5, "fallback_count": 1, "guardrail_block_count": 1}],
            "by_error_type": [{"error_type": "timeout", "total": 1}],
        },
    )
    payload = observability_api.ai_summary_detailed(hours=72)
    assert payload["summary"]["hours"] == 72
    assert len(payload["trend"]) == 1
    assert len(payload["breakdown"]["by_prompt_version"]) == 1
    assert len(payload["breakdown"]["by_model_name"]) == 1
    assert len(payload["breakdown"]["by_error_type"]) == 1
