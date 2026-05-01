from app.services.air_repository import _as_text


def test_as_text_decodes_bytes_values() -> None:
    assert _as_text(b"adult_default") == "adult_default"
    assert _as_text(bytearray(b"Europe/Madrid")) == "Europe/Madrid"
    assert _as_text("runner") == "runner"
