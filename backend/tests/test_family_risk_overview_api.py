"""Family risk overview API tests."""

from fastapi.testclient import TestClient

import app.api.deps as deps
from app.main import app
from app.models.air import ProfileType, RiskLevel, UserProfileContext
from app.models.family import FamilyMemberRiskLine, FamilyRelation
import app.services.air_repository as air_repository
import app.services.family_repository as family_repository
import app.services.family_risk_service as family_risk_service

client = TestClient(app)


def _auth() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _profile(user_id: str = "user-1", profile_id: str = "profile-child-1") -> UserProfileContext:
    return UserProfileContext(
        profile_id=profile_id,
        user_id=user_id,
        profile_type=ProfileType.CHILD,
        age_group="child",
        heat_sensitivity_level=2,
        respiratory_sensitivity_level=2,
        activity_level="moderate",
        timezone="UTC",
        home_lat=41.39,
        home_lon=2.17,
    )


def setup_function() -> None:
    family_repository.reset_store()
    family_repository.force_memory_store(True)


def teardown_function() -> None:
    family_repository.reset_store()
    family_repository.force_memory_store(False)
    app.dependency_overrides.clear()


def test_family_risk_overview_returns_member_levels(monkeypatch) -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    monkeypatch.setattr(air_repository, "get_profile_context", lambda profile_id: _profile(profile_id=profile_id))

    created = client.post(
        "/api/family/members",
        headers=_auth(),
        json={"memberProfileId": "profile-child-1", "relation": "child", "label": "Mia"},
    )
    assert created.status_code == 200

    def _fake_assess(*, owner_user_id: str, link):
        from app.models.family import FamilyMemberRiskLine, FamilyRelation

        return FamilyMemberRiskLine(
            memberLinkId=link.id,
            memberProfileId=link.memberProfileId,
            relation=FamilyRelation.CHILD,
            label=link.label,
            riskLevel=RiskLevel.HIGH.value,
            riskScore=70,
            available=True,
        )

    monkeypatch.setattr(family_risk_service, "_assess_member_risk", _fake_assess)

    response = client.get("/api/family/risk-overview", headers=_auth())
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["ownerUserId"] == "user-1"
    assert len(body["members"]) == 1
    assert body["members"][0]["riskLevel"] == "high"
    assert body["members"][0]["riskScore"] == 70
    assert body["highestRiskLevel"] == "high"


def test_family_risk_overview_empty_when_no_members() -> None:
    app.dependency_overrides[deps.get_current_user_id] = lambda: "user-1"
    response = client.get("/api/family/risk-overview", headers=_auth())
    assert response.status_code == 200
    body = response.json()
    assert body["members"] == []
    assert body["highestRiskLevel"] is None
