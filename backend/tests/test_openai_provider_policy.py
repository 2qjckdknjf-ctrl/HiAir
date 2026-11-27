import pytest

from app.services.openai_provider_policy import (
    assert_approved_openai_base_url,
    is_approved_openai_base_url,
)


def test_approved_openai_host() -> None:
    assert is_approved_openai_base_url("https://api.openai.com/v1/chat/completions")


def test_rejects_unapproved_host() -> None:
    assert not is_approved_openai_base_url("https://evil.example/v1/chat/completions")
    with pytest.raises(ValueError, match="allowlist"):
        assert_approved_openai_base_url("https://evil.example/v1/chat/completions")
