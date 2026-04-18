from app.services.privacy_repository import _as_text, _serialize_row


def test_as_text_decodes_bytes() -> None:
    assert _as_text(b"provider-sub-1") == "provider-sub-1"


def test_serialize_row_decodes_bytes_fields() -> None:
    row = {"email": b"user@example.com", "provider_subscription_id": b"sub-1"}
    serialized = _serialize_row(row)
    assert serialized["email"] == "user@example.com"
    assert serialized["provider_subscription_id"] == "sub-1"
