from fastapi.testclient import TestClient

from app.main import app
from app.services.account_deletion import AccountDeletionError, AccountDeletionOutcome, DeletionStage, StageResult, StageStatus


def _completed_outcome() -> AccountDeletionOutcome:
    return AccountDeletionOutcome(
        completed=True,
        stages=[
            StageResult(DeletionStage.PUBLIC_DATA, StageStatus.COMPLETED),
            StageResult(DeletionStage.SUPABASE_AUTH, StageStatus.SKIPPED),
            StageResult(DeletionStage.APPLE_REVOKE, StageStatus.NOT_APPLICABLE),
        ],
    )


def test_delete_account_rejects_non_delete_confirmation(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")

    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": "Bearer token"},
        json={"confirmation": "delete"},
    )
    assert response.status_code == 422, response.text
    assert response.json()["detail"] == "confirmation must be exactly DELETE"


def test_delete_account_returns_404_when_user_absent(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")

    def _raise(**_: object) -> AccountDeletionOutcome:
        raise AccountDeletionError(
            AccountDeletionOutcome(
                completed=False,
                stages=[
                    StageResult(DeletionStage.PUBLIC_DATA, StageStatus.NOT_APPLICABLE),
                    StageResult(DeletionStage.SUPABASE_AUTH, StageStatus.NOT_APPLICABLE),
                ],
            ),
            http_status=404,
        )

    monkeypatch.setattr("app.api.privacy.account_deletion_service.delete_account", _raise)

    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": "Bearer token"},
        json={"confirmation": "DELETE"},
    )
    assert response.status_code == 404, response.text


def test_delete_account_returns_deleted_true(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.privacy.account_deletion_service.delete_account",
        lambda **_: _completed_outcome(),
    )

    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": "Bearer token"},
        json={"confirmation": "DELETE"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["deleted"] is True
    assert body["stages"]["public_data"] == "completed"


def test_delete_account_revokes_apple_when_code_present(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    captured: dict[str, object] = {}

    def _delete(**kwargs: object) -> AccountDeletionOutcome:
        captured.update(kwargs)
        return _completed_outcome()

    monkeypatch.setattr("app.api.privacy.account_deletion_service.delete_account", _delete)

    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": "Bearer token"},
        json={"confirmation": "DELETE", "apple_authorization_code": "auth-code-1"},
    )
    assert response.status_code == 200, response.text
    assert captured["apple_authorization_code"] == "auth-code-1"
