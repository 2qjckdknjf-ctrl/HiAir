"""Unit tests for scripts/release/post_deploy_api_smoke.py honesty gates."""

from __future__ import annotations

import importlib.util
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]


def _load_smoke():
    path = ROOT / "scripts" / "release" / "post_deploy_api_smoke.py"
    spec = importlib.util.spec_from_file_location("post_deploy_api_smoke", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _ok_health(sha: str = "abc123def456") -> tuple[int, dict]:
    return 200, {"status": "ok", "deploy_git_sha": sha}


def _patch_parser(module, *, require_live_ai: bool) -> None:
    class _Parser:
        def add_argument(self, *args, **kwargs):  # noqa: ANN002, ANN003
            return None

        def parse_args(self):
            return SimpleNamespace(
                require_live_ai=require_live_ai,
                base_url="https://api.hiair.io",
                expect_sha="",
            )

    module.argparse.ArgumentParser = lambda **kwargs: _Parser()


def test_require_live_ai_fails_without_admin_token(monkeypatch) -> None:
    module = _load_smoke()
    monkeypatch.delenv("NOTIFICATION_ADMIN_TOKEN", raising=False)

    def fake_get(url, headers=None):  # noqa: ANN001
        if url.endswith("/api/health"):
            return _ok_health()
        if "source=sample" in url:
            return 403, {"detail": "Sample environment data is not available"}
        if "source=cached" in url:
            return 200, {"source": "cached", "aqi": 40, "temperature_c": 20.0}
        if url.endswith("/api/privacy/export"):
            return 401, {"detail": "unauthorized"}
        raise AssertionError(f"unexpected url={url}")

    monkeypatch.setattr(module, "_get", fake_get)
    _patch_parser(module, require_live_ai=True)
    assert module.main() == 1


def test_without_require_live_ai_skips_when_admin_token_missing(monkeypatch) -> None:
    module = _load_smoke()
    monkeypatch.delenv("NOTIFICATION_ADMIN_TOKEN", raising=False)

    def fake_get(url, headers=None):  # noqa: ANN001
        if url.endswith("/api/health"):
            return _ok_health()
        if "source=sample" in url:
            return 403, {"detail": "Sample environment data is not available"}
        if "source=cached" in url:
            return 200, {"source": "live", "aqi": 41, "temperature_c": 21.0}
        if url.endswith("/api/privacy/export"):
            return 401, {"detail": "unauthorized"}
        raise AssertionError(f"unexpected url={url}")

    monkeypatch.setattr(module, "_get", fake_get)
    _patch_parser(module, require_live_ai=False)
    assert module.main() == 0


def test_smoke_fails_if_sample_source_served(monkeypatch) -> None:
    module = _load_smoke()
    monkeypatch.delenv("NOTIFICATION_ADMIN_TOKEN", raising=False)

    def fake_get(url, headers=None):  # noqa: ANN001
        if url.endswith("/api/health"):
            return _ok_health()
        if "source=sample" in url:
            return 200, {"source": "sample", "aqi": 1, "temperature_c": 20.0}
        raise AssertionError(f"unexpected url={url}")

    monkeypatch.setattr(module, "_get", fake_get)
    _patch_parser(module, require_live_ai=False)
    assert module.main() == 1
