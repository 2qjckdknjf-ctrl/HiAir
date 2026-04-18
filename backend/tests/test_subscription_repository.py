from app.services.subscription_repository import _as_text


def test_as_text_supports_bytes() -> None:
    assert _as_text(b"trialing") == "trialing"


def test_as_text_supports_str_and_none() -> None:
    assert _as_text("active") == "active"
    assert _as_text(None) is None
