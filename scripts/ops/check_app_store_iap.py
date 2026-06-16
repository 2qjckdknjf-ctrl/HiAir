#!/usr/bin/env python3
"""List HiAir subscription IAP state in App Store Connect (diagnostic)."""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import jwt
import httpx

ROOT = Path(__file__).resolve().parents[2]
SECRETS = ROOT / "backend" / ".secrets"
BUNDLE_ID = "com.hiair.app"
PRODUCT_IDS = ("com.hiair.premium.monthly", "com.hiair.premium.yearly")


def _load_issuer() -> str:
    env = os.environ.get("APPLE_ISSUER_ID", "").strip()
    if env:
        return env
    path = SECRETS / "apple_issuer_id"
    if path.is_file():
        return path.read_text(encoding="utf-8").strip()
    raise SystemExit("APPLE_ISSUER_ID missing (env or backend/.secrets/apple_issuer_id)")


def _load_key() -> tuple[str, str]:
    key_id = os.environ.get("APPLE_KEY_ID", "VCL6R84SP3").strip()
    key_path = Path(os.environ.get("APPLE_KEY_PATH", SECRETS / f"AuthKey_{key_id}.p8"))
    if not key_path.is_file():
        raise SystemExit(f"API key not found: {key_path}")
    return key_id, key_path.read_text(encoding="utf-8")


def _token(key_id: str, key_pem: str, issuer: str) -> str:
    now = int(time.time())
    payload = {
        "iss": issuer,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, key_pem, algorithm="ES256", headers={"kid": key_id})


def main() -> int:
    issuer = _load_issuer()
    key_id, key_pem = _load_key()
    token = _token(key_id, key_pem, issuer)
    headers = {"Authorization": f"Bearer {token}"}

    with httpx.Client(timeout=60.0, headers=headers) as client:
        apps = client.get(
            "https://api.appstoreconnect.apple.com/v1/apps",
            params={"filter[bundleId]": BUNDLE_ID},
        )
        apps.raise_for_status()
        data = apps.json().get("data") or []
        if not data:
            print(f"FAIL: no app with bundleId={BUNDLE_ID}")
            return 1
        app_id = data[0]["id"]
        print(f"OK app {BUNDLE_ID} id={app_id}")

        groups = client.get(
            f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/subscriptionGroups",
            params={"include": "subscriptions", "limit": 50},
        )
        groups.raise_for_status()
        included = {item["id"]: item for item in groups.json().get("included") or []}
        found: set[str] = set()
        for group in groups.json().get("data") or []:
            attrs = group.get("attributes") or {}
            print(f"\nGroup: {attrs.get('referenceName', group['id'])}")
            for rel in group.get("relationships", {}).get("subscriptions", {}).get("data") or []:
                sub = included.get(rel["id"])
                if not sub:
                    continue
                sa = sub.get("attributes") or {}
                pid = sa.get("productId") or ""
                state = sa.get("state") or "?"
                found.add(pid)
                sub_id = sub["id"]
                prices = client.get(
                    f"https://api.appstoreconnect.apple.com/v1/subscriptions/{sub_id}/prices",
                    params={"limit": 1},
                )
                if prices.status_code == 200:
                    price_count = (
                        ((prices.json().get("meta") or {}).get("paging") or {}).get("total")
                        or len(prices.json().get("data") or [])
                    )
                else:
                    price_count = 0
                screenshot = client.get(
                    f"https://api.appstoreconnect.apple.com/v1/subscriptions/{sub_id}/appStoreReviewScreenshot"
                )
                has_screenshot = screenshot.status_code == 200 and bool(screenshot.json().get("data"))
                availability = client.get(
                    f"https://api.appstoreconnect.apple.com/v1/subscriptions/{sub_id}/subscriptionAvailability"
                )
                has_availability = availability.status_code == 200 and bool(availability.json().get("data"))
                shot_state = ""
                if has_screenshot:
                    shot_attrs = screenshot.json()["data"].get("attributes") or {}
                    shot_state = (
                        (shot_attrs.get("assetDeliveryState") or {}).get("state") or "present"
                    )
                print(
                    f"  - {pid} state={state} name={sa.get('name', '')} "
                    f"prices={price_count} availability={'yes' if has_availability else 'no'} "
                    f"review_screenshot={'yes' if has_screenshot else 'no'}"
                    + (f" ({shot_state})" if shot_state else "")
                )

        missing = [p for p in PRODUCT_IDS if p not in found]
        if missing:
            print(f"\nFAIL: missing product IDs in App Store Connect: {', '.join(missing)}")
            print("Create HiAir Premium group + monthly/yearly subs and link to the TestFlight app version.")
            return 1
        print(f"\nOK: all expected product IDs present: {', '.join(PRODUCT_IDS)}")
        return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except httpx.HTTPStatusError as exc:
        print(f"HTTP {exc.response.status_code}: {exc.response.text[:500]}", file=sys.stderr)
        raise SystemExit(1) from exc
