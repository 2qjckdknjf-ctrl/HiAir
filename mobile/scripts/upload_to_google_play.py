#!/usr/bin/env python3
"""Upload HiAir Android AAB to Google Play internal track."""

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


def main() -> int:
    parser = argparse.ArgumentParser(description="Upload AAB to Google Play.")
    parser.add_argument(
        "--aab",
        default="mobile/android/app/build/outputs/bundle/release/app-release.aab",
        help="Path to signed AAB file",
    )
    parser.add_argument(
        "--service-account-json",
        default=os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", ""),
        help="Service account JSON string or path to JSON file",
    )
    parser.add_argument("--track", default="internal", choices=["internal", "alpha", "beta", "production"])
    parser.add_argument("--release-name", default="HiAir internal release")
    parser.add_argument("--status", default="completed", choices=["completed", "draft", "inProgress", "halted"])
    args = parser.parse_args()

    aab_path = Path(args.aab)
    if not aab_path.exists():
        print(f"AAB not found: {aab_path}", file=sys.stderr)
        return 1

    credentials = _load_credentials(args.service_account_json)
    if credentials is None:
        print(
            "Missing Google Play service account credentials. "
            "Set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON or pass --service-account-json.",
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
        print(f"Uploaded bundle versionCode={version_code}")

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
        print(f"Assigned version {version_code} to track '{args.track}'")

        commit = service.edits().commit(editId=edit_id, packageName=PACKAGE_NAME).execute()
        print(f"Committed edit: {commit.get('id', edit_id)}")
    except Exception:
        service.edits().delete(editId=edit_id, packageName=PACKAGE_NAME).execute()
        raise

    return 0


def _load_credentials(raw: str):
    if not raw:
        default_path = Path.home() / ".hiair-secrets" / "play-service-account.json"
        if default_path.exists():
            raw = default_path.read_text(encoding="utf-8")
        else:
            return None

    path = Path(raw)
    if path.exists():
        info = json.loads(path.read_text(encoding="utf-8"))
    else:
        info = json.loads(raw)

    return service_account.Credentials.from_service_account_info(info, scopes=SCOPES)


if __name__ == "__main__":
    raise SystemExit(main())
