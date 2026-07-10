#!/usr/bin/env python3
"""Upload signed HiAir AAB to Google Play Internal testing track."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE_NAME = "com.hiair"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
DEFAULT_JSON = Path(__file__).resolve().parents[2] / "backend/.secrets/google-play-service-account.json"


def _load_credentials(raw: str):
    if not raw:
        candidates = [
            DEFAULT_JSON,
            Path.home() / ".hiair-secrets/play-service-account.json",
        ]
        for candidate in candidates:
            if candidate.exists():
                raw = str(candidate)
                break
        else:
            return None

    path = Path(raw)
    if path.exists():
        info = json.loads(path.read_text(encoding="utf-8"))
    else:
        info = json.loads(raw)

    return service_account.Credentials.from_service_account_info(info, scopes=SCOPES)


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description="Upload signed AAB to Google Play internal track.")
    parser.add_argument(
        "--aab",
        default=str(root / "mobile/android/app/build/outputs/bundle/release/app-release.aab"),
    )
    parser.add_argument(
        "--service-account-json",
        default=os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", ""),
    )
    parser.add_argument("--track", default="internal", choices=["internal", "alpha", "beta", "production"])
    parser.add_argument("--release-name", default="HiAir 0.1.0 internal")
    parser.add_argument("--status", default="completed", choices=["completed", "draft", "inProgress", "halted"])
    args = parser.parse_args()

    aab_path = Path(args.aab)
    if not aab_path.is_file():
        print(f"error: AAB not found: {aab_path}", file=sys.stderr)
        return 1

    credentials = _load_credentials(args.service_account_json)
    if credentials is None:
        print(
            "error: Google Play service account JSON missing. "
            "Place at backend/.secrets/google-play-service-account.json (gitignored).",
            file=sys.stderr,
        )
        return 1

    service = build("androidpublisher", "v3", credentials=credentials, cache_discovery=False)
    edit_id = service.edits().insert(body={}, packageName=PACKAGE_NAME).execute()["id"]

    try:
        media = MediaFileUpload(str(aab_path), mimetype="application/octet-stream", resumable=True)
        bundle = (
            service.edits()
            .bundles()
            .upload(editId=edit_id, packageName=PACKAGE_NAME, media_body=media)
            .execute()
        )
        version_code = bundle["versionCode"]
        print(f"uploaded versionCode={version_code} package={PACKAGE_NAME}")

        track_body = {
            "track": args.track,
            "releases": [
                {
                    "name": args.release_name,
                    "status": args.status,
                    "versionCodes": [str(version_code)],
                }
            ],
        }
        service.edits().tracks().update(
            editId=edit_id,
            packageName=PACKAGE_NAME,
            track=args.track,
            body=track_body,
        ).execute()
        print(f"assigned track={args.track} status={args.status}")

        commit = service.edits().commit(editId=edit_id, packageName=PACKAGE_NAME).execute()
        print(f"committed edit={commit.get('id', edit_id)}")
    except Exception:
        service.edits().delete(editId=edit_id, packageName=PACKAGE_NAME).execute()
        raise

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
