from app.services.security import hash_password, validate_password_policy, verify_password


def test_verify_password_accepts_text_hash() -> None:
    encoded = hash_password("strongpass123")
    assert verify_password("strongpass123", encoded) is True


def test_verify_password_accepts_bytes_hash() -> None:
    encoded = hash_password("strongpass123")
    assert verify_password("strongpass123", encoded.encode("utf-8")) is True


def test_password_policy_requires_strong_secret() -> None:
    weak_ok, _ = validate_password_policy("weakpassword")
    assert weak_ok is False
    strong_ok, _ = validate_password_policy("StrongPass#123")
    assert strong_ok is True
