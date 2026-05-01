from fastapi.testclient import TestClient

from app.main import app


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
    monkeypatch.setattr(
        "app.api.privacy.privacy_repository.delete_user_data",
        lambda **_: False,
    )

    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": "Bearer token"},
        json={"confirmation": "DELETE"},
    )
    assert response.status_code == 404, response.text
    assert response.json()["detail"] == "User not found"


def test_delete_account_returns_deleted_true(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.privacy.privacy_repository.delete_user_data",
        lambda **_: True,
    )

    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": "Bearer token"},
        json={"confirmation": "DELETE"},
    )
    assert response.status_code == 200, response.text
    assert response.json() == {"deleted": True}
