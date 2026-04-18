from types import SimpleNamespace

import httpx

from app.models.air import (
    ProfileType,
    RecommendationCard,
    RiskAssessmentResult,
    RiskLevel,
    UserProfileContext,
)
from app.services import ai_explanation_service


def build_profile() -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=ProfileType.ADULT_DEFAULT,
        age_group="adult",
        heat_sensitivity_level=2,
        respiratory_sensitivity_level=2,
        activity_level="moderate",
        timezone="UTC",
        home_lat=41.39,
        home_lon=2.17,
    )


def build_risk() -> RiskAssessmentResult:
    return RiskAssessmentResult(
        overallRisk=RiskLevel.HIGH,
        heatRisk=RiskLevel.HIGH,
        airRisk=RiskLevel.MODERATE,
        outdoorRisk=RiskLevel.HIGH,
        indoorVentilationRisk=RiskLevel.MODERATE,
        safeWindows=[],
        recommendationFlags=["avoid_outdoor_now"],
        reasonCodes=["high_heat"],
    )


def test_fallback_when_api_key_missing(monkeypatch) -> None:
    monkeypatch.setattr(
        ai_explanation_service,
        "settings",
        SimpleNamespace(
            openai_api_key="",
            openai_model="gpt-4o-mini",
            openai_base_url="https://api.openai.com/v1/chat/completions",
            openai_prompt_version="hiair-expl-v1",
        ),
    )
    monkeypatch.setattr(ai_explanation_service, "ensure_prompt_version", lambda **kwargs: None)
    monkeypatch.setattr(ai_explanation_service, "save_explanation_event", lambda **kwargs: "event-1")
    text, source = ai_explanation_service.generate_explanation(
        build_profile(),
        build_risk(),
        RecommendationCard(headline="h", summary="s", actions=["a"]),
        risk_assessment_id="assessment-1",
    )
    assert source == "template_fallback"
    assert "уровень риска" in text


def test_guardrail_blocks_unsafe_text(monkeypatch) -> None:
    class FakeResponse:
        def raise_for_status(self) -> None:
            return None

        def json(self) -> dict:
            return {"choices": [{"message": {"content": "Это диагноз и вам срочно нужно лечение"}}]}

    class FakeClient:
        def __init__(self, timeout: float) -> None:
            self.timeout = timeout

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb) -> None:
            return None

        def post(self, url: str, json: dict, headers: dict) -> FakeResponse:
            return FakeResponse()

    monkeypatch.setattr(
        ai_explanation_service,
        "settings",
        SimpleNamespace(
            openai_api_key="test-key",
            openai_model="gpt-4o-mini",
            openai_base_url="https://api.openai.com/v1/chat/completions",
            openai_prompt_version="hiair-expl-v1",
        ),
    )
    monkeypatch.setattr(ai_explanation_service, "ensure_prompt_version", lambda **kwargs: None)
    monkeypatch.setattr(ai_explanation_service, "save_explanation_event", lambda **kwargs: "event-1")
    monkeypatch.setattr(ai_explanation_service.httpx, "Client", FakeClient)
    text, source = ai_explanation_service.generate_explanation(
        build_profile(),
        build_risk(),
        RecommendationCard(headline="h", summary="s", actions=["a"]),
        risk_assessment_id="assessment-1",
    )
    assert source == "template_fallback"
    assert "диагноз" not in text.lower()


def test_classify_llm_failure_timeout() -> None:
    request = httpx.Request("POST", "https://api.openai.com/v1/chat/completions")
    exc = httpx.ReadTimeout("timeout", request=request)
    assert ai_explanation_service._classify_llm_failure(exc) == "llm_timeout"


def test_classify_llm_failure_network() -> None:
    request = httpx.Request("POST", "https://api.openai.com/v1/chat/completions")
    exc = httpx.ConnectError("network", request=request)
    assert ai_explanation_service._classify_llm_failure(exc) == "llm_network_error"


def test_classify_llm_failure_server_status() -> None:
    request = httpx.Request("POST", "https://api.openai.com/v1/chat/completions")
    response = httpx.Response(status_code=503, request=request)
    exc = httpx.HTTPStatusError("status", request=request, response=response)
    assert ai_explanation_service._classify_llm_failure(exc) == "llm_server_error"
