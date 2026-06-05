from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from app.main import create_app


def test_waitlist_rejects_invalid_email() -> None:
    client = TestClient(create_app())
    response = client.post("/api/waitlist", json={"email": "not-an-email"})
    assert response.status_code == 422


def test_waitlist_rejects_invalid_persona() -> None:
    client = TestClient(create_app())
    response = client.post(
        "/api/waitlist",
        json={"email": "user@example.com", "persona": "invalid_persona"},
    )
    assert response.status_code == 422


@patch("app.api.waitlist.connect")
def test_waitlist_accepts_signup(mock_connect: MagicMock) -> None:
    mock_conn = MagicMock()
    mock_cur = MagicMock()
    mock_cur.fetchone.return_value = ("00000000-0000-0000-0000-000000000001",)
    mock_conn.cursor.return_value.__enter__.return_value = mock_cur
    mock_connect.return_value.__enter__.return_value = mock_conn

    client = TestClient(create_app())
    response = client.post(
        "/api/waitlist",
        json={"email": "early@example.com", "persona": "parent"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert "early access" in body["message"].lower()
