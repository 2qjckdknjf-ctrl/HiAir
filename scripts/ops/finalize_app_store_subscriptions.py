#!/usr/bin/env python3
"""Set subscription prices, upload review screenshots, and report ASC readiness."""

from __future__ import annotations

import hashlib
import json
import os
import sys
import time
from pathlib import Path

import httpx
import jwt

ROOT = Path(__file__).resolve().parents[2]
SECRETS = ROOT / "backend" / ".secrets"
BUNDLE_ID = "com.hiair.app"
GROUP_NAME = "HiAir Premium"
REVIEW_SCREENSHOT = ROOT / "docs/brand/store-assets/subscription-review-screenshot.png"
PRODUCTS = (
    ("com.hiair.premium.monthly", 4.99),
    ("com.hiair.premium.yearly", 39.99),
)


def _issuer() -> str:
    env = os.environ.get("APPLE_ISSUER_ID", "").strip()
    if env:
        return env
    return (SECRETS / "apple_issuer_id").read_text(encoding="utf-8").strip()


def _key() -> tuple[str, str]:
    key_id = os.environ.get("APPLE_KEY_ID", "VCL6R84SP3").strip()
    path = Path(os.environ.get("APPLE_KEY_PATH", SECRETS / f"AuthKey_{key_id}.p8"))
    return key_id, path.read_text(encoding="utf-8")


def _token(key_id: str, pem: str, issuer: str) -> str:
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        pem,
        algorithm="ES256",
        headers={"kid": key_id},
    )


def _paginate_price_points(client: httpx.Client, subscription_id: str, territory: str = "USA") -> list[dict]:
    url: str | None = f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}/pricePoints"
    params: dict[str, object] | None = {"filter[territory]": territory, "limit": 200}
    out: list[dict] = []
    while url:
        r = client.get(url, params=params)
        r.raise_for_status()
        payload = r.json()
        out.extend(payload.get("data") or [])
        url = (payload.get("links") or {}).get("next")
        params = None
    return out


def _find_price_point(points: list[dict], target_usd: float) -> dict | None:
    best: dict | None = None
    best_diff = 1e9
    for item in points:
        raw = (item.get("attributes") or {}).get("customerPrice")
        if raw is None:
            continue
        try:
            price = float(raw)
        except (TypeError, ValueError):
            continue
        diff = abs(price - target_usd)
        if diff < best_diff:
            best_diff = diff
            best = item
    return best


def _set_usa_price(client: httpx.Client, subscription_id: str, target_usd: float) -> bool:
    existing = client.get(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}/prices",
        params={"limit": 1},
    )
    if existing.status_code == 200 and existing.json().get("data"):
        print(f"    price already set ({len(existing.json()['data'])} entries)")
        return True

    points = _paginate_price_points(client, subscription_id)
    point = _find_price_point(points, target_usd)
    if point is None:
        print(f"    WARN: no USA price point near ${target_usd}")
        return False
    point_id = point["id"]
    actual = (point.get("attributes") or {}).get("customerPrice")
    body = {
        "data": {
            "type": "subscriptions",
            "id": subscription_id,
            "relationships": {
                "prices": {"data": [{"type": "subscriptionPrices", "id": "${price1}"}]}
            },
        },
        "included": [
            {
                "type": "subscriptionPrices",
                "id": "${price1}",
                "attributes": {"preserveCurrentPrice": False},
                "relationships": {
                    "subscription": {"data": {"type": "subscriptions", "id": subscription_id}},
                    "subscriptionPricePoint": {
                        "data": {"type": "subscriptionPricePoints", "id": point_id}
                    },
                    "territory": {"data": {"type": "territories", "id": "USA"}},
                },
            }
        ],
    }
    r = client.patch(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}",
        json=body,
    )
    if r.status_code != 200:
        print(f"    price PATCH failed {r.status_code}: {r.text[:300]}")
        return False
    print(f"    price USA ${actual} (target ${target_usd})")
    return True


def _upload_review_screenshot(client: httpx.Client, subscription_id: str, image_path: Path) -> bool:
    check = client.get(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}/appStoreReviewScreenshot"
    )
    if check.status_code == 200 and check.json().get("data"):
        state = ((check.json()["data"].get("attributes") or {}).get("assetDeliveryState") or {}).get("state")
        print(f"    review screenshot exists (state={state})")
        return True

    raw = image_path.read_bytes()
    reserve_body = {
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "attributes": {
                "fileName": image_path.name,
                "fileSize": len(raw),
            },
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": subscription_id}},
            },
        }
    }
    r = client.post(
        "https://api.appstoreconnect.apple.com/v1/subscriptionAppStoreReviewScreenshots",
        json=reserve_body,
    )
    if r.status_code not in (201, 200):
        print(f"    screenshot reserve failed {r.status_code}: {r.text[:400]}")
        return False
    asset = r.json()["data"]
    asset_id = asset["id"]
    ops = (asset.get("attributes") or {}).get("uploadOperations") or []
    if not ops:
        print("    screenshot reserve returned no upload operations")
        return False

    for op in ops:
        start = int(op["offset"])
        end = start + int(op["length"])
        chunk = raw[start:end]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders") or []}
        up = client.request(op["method"], op["url"], headers=headers, content=chunk)
        if up.status_code not in (200, 201, 204):
            print(f"    screenshot upload failed {up.status_code}")
            return False

    checksum = hashlib.md5(raw).hexdigest()
    commit_body = {
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "id": asset_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
        }
    }
    cr = client.patch(
        f"https://api.appstoreconnect.apple.com/v1/subscriptionAppStoreReviewScreenshots/{asset_id}",
        json=commit_body,
    )
    if cr.status_code != 200:
        print(f"    screenshot commit failed {cr.status_code}: {cr.text[:400]}")
        return False
    print("    review screenshot uploaded")
    return True


def main() -> int:
    if not REVIEW_SCREENSHOT.is_file():
        raise SystemExit(f"Missing review screenshot: {REVIEW_SCREENSHOT}")

    issuer = _issuer()
    key_id, pem = _key()
    headers = {
        "Authorization": f"Bearer {_token(key_id, pem, issuer)}",
        "Content-Type": "application/json",
    }
    with httpx.Client(timeout=120.0, headers=headers) as client:
        apps = client.get(
            "https://api.appstoreconnect.apple.com/v1/apps",
            params={"filter[bundleId]": BUNDLE_ID},
        )
        apps.raise_for_status()
        app_id = apps.json()["data"][0]["id"]
        groups = client.get(
            f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/subscriptionGroups",
            params={"include": "subscriptions", "limit": 50},
        )
        groups.raise_for_status()
        included = {item["id"]: item for item in groups.json().get("included") or []}
        group_id = None
        subs_by_product: dict[str, dict] = {}
        for group in groups.json().get("data") or []:
            if (group.get("attributes") or {}).get("referenceName") == GROUP_NAME:
                group_id = group["id"]
                for rel in group.get("relationships", {}).get("subscriptions", {}).get("data") or []:
                    sub = included.get(rel["id"])
                    if sub:
                        pid = (sub.get("attributes") or {}).get("productId")
                        if pid:
                            subs_by_product[pid] = sub
        if not group_id:
            raise SystemExit(f"Subscription group not found: {GROUP_NAME}")

        print(f"App {BUNDLE_ID} group={group_id}")
        for product_id, target_usd in PRODUCTS:
            sub = subs_by_product.get(product_id)
            if not sub:
                print(f"FAIL missing subscription {product_id}")
                return 1
            sub_id = sub["id"]
            state = (sub.get("attributes") or {}).get("state")
            print(f"\n{product_id} id={sub_id} state={state}")
            _set_usa_price(client, sub_id, target_usd)
            _upload_review_screenshot(client, sub_id, REVIEW_SCREENSHOT)
            refreshed = client.get(f"https://api.appstoreconnect.apple.com/v1/subscriptions/{sub_id}")
            refreshed.raise_for_status()
            new_state = (refreshed.json()["data"].get("attributes") or {}).get("state")
            prices = client.get(
                f"https://api.appstoreconnect.apple.com/v1/subscriptions/{sub_id}/prices",
                params={"limit": 1},
            )
            price_count = len(prices.json().get("data") or [])
            shot = client.get(
                f"https://api.appstoreconnect.apple.com/v1/subscriptions/{sub_id}/appStoreReviewScreenshot"
            )
            has_shot = shot.status_code == 200 and bool(shot.json().get("data"))
            print(f"  => state={new_state} prices={price_count} review_screenshot={'yes' if has_shot else 'no'}")

    print("\nIf state is still MISSING_METADATA:")
    print("  Link subscriptions to app version 1.0 in App Store Connect UI")
    print("  (App → Distribution → version → In-App Purchases and Subscriptions)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except httpx.HTTPStatusError as exc:
        print(exc.response.text[:800], file=sys.stderr)
        raise SystemExit(1) from exc
