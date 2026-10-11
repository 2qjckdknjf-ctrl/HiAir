from contextlib import contextmanager
import pytest
from psycopg import OperationalError
from fastapi.testclient import TestClient
from app.api.deps import get_current_user_id
from app.main import app
from app.services import travel_repository


def test_travel_clear_returns_503_when_database_update_fails(monkeypatch):
    @contextmanager
    def failed_connection():
        raise OperationalError("database unavailable")
        yield
    monkeypatch.setattr(travel_repository, '_FORCE_MEMORY', False)
    monkeypatch.setattr(travel_repository, 'get_connection', failed_connection)
    app.dependency_overrides[get_current_user_id] = lambda: 'test-user'
    try:
        result = TestClient(app).delete('/api/travel/session')
        assert result.status_code == 503
        assert result.json()['detail'] == 'Database unavailable'
    finally:
        app.dependency_overrides.clear()
