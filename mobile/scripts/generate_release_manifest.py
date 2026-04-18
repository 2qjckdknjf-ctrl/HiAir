from __future__ import annotations

import argparse
import hashlib
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path


@dataclass
class ArtifactInfo:
    label: str
    path: Path
    exists: bool
    size_bytes: int | None
    sha256: str | None


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate release artifacts manifest for iOS/Android uploads.")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail if mandatory artifacts are missing (Android AAB and iOS xcarchive).",
    )
    args = parser.parse_args()

    mobile_root = Path(__file__).resolve().parents[1]
    repo_root = mobile_root.parent
    docs_dir = repo_root / "docs"
    docs_dir.mkdir(parents=True, exist_ok=True)

    candidates = [
        ("Android AAB", mobile_root / "android/app/build/outputs/bundle/release/app-release.aab"),
        ("Android debug APK", mobile_root / "android/app/build/outputs/apk/debug/app-debug.apk"),
        ("iOS xcarchive", mobile_root / "ios/build/HiAir.xcarchive"),
        ("iOS IPA", mobile_root / "ios/build/HiAir.ipa"),
    ]

    artifacts = [_artifact_info(label, path) for label, path in candidates]
    manifest_path = docs_dir / "release-artifacts-manifest.md"
    manifest_path.write_text(_render_manifest(artifacts), encoding="utf-8")

    for item in artifacts:
        if item.exists:
            print(f"[FOUND] {item.label}: {item.path}")
        else:
            print(f"[MISSING] {item.label}: {item.path}")
    print(f"Manifest written: {manifest_path}")

    if args.strict:
        mandatory = {
            "Android AAB": False,
            "iOS xcarchive": False,
        }
        for item in artifacts:
            if item.label in mandatory and item.exists:
                mandatory[item.label] = True
        missing = [name for name, ok in mandatory.items() if not ok]
        if missing:
            print(f"Strict mode failed. Missing mandatory artifacts: {', '.join(missing)}")
            return 1

    return 0


def _artifact_info(label: str, path: Path) -> ArtifactInfo:
    if not path.exists():
        return ArtifactInfo(label=label, path=path, exists=False, size_bytes=None, sha256=None)
    if path.is_dir():
        size = _dir_size(path)
        digest = _dir_digest(path)
    else:
        size = path.stat().st_size
        digest = _file_digest(path)
    return ArtifactInfo(label=label, path=path, exists=True, size_bytes=size, sha256=digest)


def _file_digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


def _dir_digest(path: Path) -> str:
    hasher = hashlib.sha256()
    for child in sorted(p for p in path.rglob("*") if p.is_file()):
        hasher.update(str(child.relative_to(path)).encode("utf-8"))
        hasher.update(_file_digest(child).encode("utf-8"))
    return hasher.hexdigest()


def _dir_size(path: Path) -> int:
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


def _render_manifest(artifacts: list[ArtifactInfo]) -> str:
    now = datetime.now(tz=UTC).isoformat()
    lines = [
        "# HiAir Release Artifacts Manifest",
        "",
        f"Generated at (UTC): {now}",
        "",
        "| Artifact | Exists | Path | Size (bytes) | SHA256 |",
        "|---|---|---|---:|---|",
    ]
    for item in artifacts:
        exists = "yes" if item.exists else "no"
        size = str(item.size_bytes) if item.size_bytes is not None else "-"
        sha = item.sha256 or "-"
        lines.append(
            f"| {item.label} | {exists} | `{item.path}` | {size} | `{sha}` |"
        )
    lines.append("")
    lines.append("Use this file as upload evidence for TestFlight/Internal Test.")
    return "\n".join(lines)


if __name__ == "__main__":
    raise SystemExit(main())
