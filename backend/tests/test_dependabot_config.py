from pathlib import Path


def test_dependabot_config_covers_backend_actions_android() -> None:
    root = Path(__file__).resolve().parents[2]
    config = (root / ".github" / "dependabot.yml").read_text(encoding="utf-8")
    assert "package-ecosystem: \"pip\"" in config
    assert "directory: \"/backend\"" in config
    assert "package-ecosystem: \"github-actions\"" in config
    assert "package-ecosystem: \"gradle\"" in config
    assert "directory: \"/mobile/android\"" in config
    # web/ has no package.json — npm ecosystem must stay absent.
    assert "package-ecosystem: \"npm\"" not in config
