from app.services.security import hash_password, verify_password


def test_verify_password_accepts_text_hash() -> None:
    encoded = hash_password("strongpass123")
    assert verify_password("strongpass123", encoded) is True


def test_verify_password_accepts_bytes_hash() -> None:
    encoded = hash_password("strongpass123")
    assert verify_password("strongpass123", encoded.encode("utf-8")) is True
