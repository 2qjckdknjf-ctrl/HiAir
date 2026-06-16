#!/usr/bin/env python3
"""Finalize HiAir Premium subscriptions: prices, screenshots, readiness report."""

from __future__ import annotations

import base64
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


def _paginate(client: httpx.Client, url: str, params: dict[str, object] | None = None) -> list[dict]:
    out: list[dict] = []
    next_url: str | None = url
    next_params = params
    while next_url:
        r = client.get(next_url, params=next_params)
        r.raise_for_status()
        payload = r.json()
        out.extend(payload.get("data") or [])
        next_url = (payload.get("links") or {}).get("next")
        next_params = None
    return out


def _territory_from_price_point(point_id: str) -> str:
    padded = point_id + "=" * (-len(point_id) % 4)
    decoded = json.loads(base64.urlsafe_b64decode(padded))
    return str(decoded.get("t") or "USA")


def _find_usa_price_point(client: httpx.Client, subscription_id: str, target: float) -> str | None:
    points = _paginate(
        client,
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}/pricePoints",
        {"filter[territory]": "USA", "limit": 200},
    )
    best_id: str | None = None
    best_diff = 1e9
    for item in points:
        raw = (item.get("attributes") or {}).get("customerPrice")
        if raw is None:
            continue
        try:
            price = float(raw)
        except (TypeError, ValueError):
            continue
        diff = abs(price - target)
        if diff < best_diff:
            best_diff = diff
            best_id = item["id"]
    return best_id


def _propagate_equalized_prices(client: httpx.Client, subscription_id: str, target_usd: float) -> None:
    existing = client.get(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}/prices",
        params={"limit": 1},
    )
    total = ((existing.json().get("meta") or {}).get("paging") or {}).get("total", 0)
    if isinstance(total, int) and total >= 100:
        print(f"    prices already propagated ({total} territories)")
        return

    point_id = _find_usa_price_point(client, subscription_id, target_usd)
    if not point_id:
        print(f"    WARN: no USA price point near ${target_usd}")
        return
    equalizations = _paginate(
        client,
        f"https://api.appstoreconnect.apple.com/v1/subscriptionPricePoints/{point_id}/equalizations",
        {"limit": 200},
    )
    relationships: list[dict[str, str]] = []
    included: list[dict] = []
    for index, point in enumerate(equalizations):
        local_id = f"${{price{index}}}"
        territory = _territory_from_price_point(point["id"])
        relationships.append({"type": "subscriptionPrices", "id": local_id})
        included.append(
            {
                "type": "subscriptionPrices",
                "id": local_id,
                "attributes": {"preserveCurrentPrice": False},
                "relationships": {
                    "subscription": {
                        "data": {"type": "subscriptions", "id": subscription_id}
                    },
                    "subscriptionPricePoint": {
                        "data": {"type": "subscriptionPricePoints", "id": point["id"]}
                    },
                    "territory": {"data": {"type": "territories", "id": territory}},
                },
            }
        )
    body = {
        "data": {
            "type": "subscriptions",
            "id": subscription_id,
            "relationships": {"prices": {"data": relationships}},
        },
        "included": included,
    }
    r = client.patch(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}",
        json=body,
    )
    r.raise_for_status()
    refreshed = client.get(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}/prices",
        params={"limit": 1},
    )
    count = ((refreshed.json().get("meta") or {}).get("paging") or {}).get("total", "?")
    print(f"    prices propagated to {count} territories (USA ~${target_usd})")


def _upload_review_screenshot(client: httpx.Client, subscription_id: str, image_path: Path) -> None:
    shot = client.get(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}/appStoreReviewScreenshot"
    )
    if shot.status_code == 200 and shot.json().get("data"):
        state = (
            (shot.json()["data"].get("attributes") or {})
            .get("assetDeliveryState", {})
            .get("state")
        )
        if state in {"COMPLETE", "UPLOAD_COMPLETE"}:
            print(f"    review screenshot ready ({state})")
            return
        asset_id = shot.json()["data"]["id"]
        client.delete(
            f"https://api.appstoreconnect.apple.com/v1/subscriptionAppStoreReviewScreenshots/{asset_id}"
        )

    raw = image_path.read_bytes()
    reserve = client.post(
        "https://api.appstoreconnect.apple.com/v1/subscriptionAppStoreReviewScreenshots",
        json={
            "data": {
                "type": "subscriptionAppStoreReviewScreenshots",
                "attributes": {"fileName": image_path.name, "fileSize": len(raw)},
                "relationships": {
                    "subscription": {"data": {"type": "subscriptions", "id": subscription_id}}
                },
            }
        },
    )
    reserve.raise_for_status()
    asset = reserve.json()["data"]
    asset_id = asset["id"]
    for op in (asset.get("attributes") or {}).get("uploadOperations") or []:
        start = int(op["offset"])
        end = start + int(op["length"])
        chunk = raw[start:end]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders") or []}
        up = client.request(op["method"], op["url"], headers=headers, content=chunk)
        up.raise_for_status()

    checksum = hashlib.md5(raw).hexdigest()
    commit = client.patch(
        f"https://api.appstoreconnect.apple.com/v1/subscriptionAppStoreReviewScreenshots/{asset_id}",
        json={
            "data": {
                "type": "subscriptionAppStoreReviewScreenshots",
                "id": asset_id,
                "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
            }
        },
    )
    commit.raise_for_status()
    print("    review screenshot uploaded")


def main() -> int:
    if not REVIEW_SCREENSHOT.is_file():
        raise SystemExit(f"Missing review screenshot: {REVIEW_SCREENSHOT}")

    issuer = _issuer()
    key_id, pem = _key()
    headers = {
        "Authorization": f"Bearer {_token(key_id, pem, issuer)}",
        "Content-Type": "application/json",
    }
    with httpx.Client(timeout=180.0, headers=headers) as client:
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
        subs_by_product: dict[str, dict] = {}
        for group in groups.json().get("data") or []:
            if (group.get("attributes") or {}).get("referenceName") != GROUP_NAME:
                continue
            for rel in group.get("relationships", {}).get("subscriptions", {}).get("data") or []:
                sub = included.get(rel["id"])
                if not sub:
                    continue
                pid = (sub.get("attributes") or {}).get("productId")
                if pid:
                    subs_by_product[pid] = sub

        print(f"App {BUNDLE_ID}")
        all_ready = True
        for product_id, target_usd in PRODUCTS:
            sub = subs_by_product.get(product_id)
            if not sub:
                print(f"FAIL missing subscription {product_id}")
                return 1
            sub_id = sub["id"]
            print(f"\n{product_id} id={sub_id}")
            _propagate_equalized_prices(client, sub_id, target_usd)
            _upload_review_screenshot(client, sub_id, REVIEW_SCREENSHOT)
            refreshed = client.get(f"https://api.appstoreconnect.apple.com/v1/subscriptions/{sub_id}")
            refreshed.raise_for_status()
            state = (refreshed.json()["data"].get("attributes") or {}).get("state")
            prices = client.get(
                f"https://api.appstoreconnect.apple.com/v1/subscriptions/{sub_id}/prices",
                params={"limit": 1},
            )
            price_count = ((prices.json().get("meta") or {}).get("paging") or {}).get("total", 0)
            print(f"  => state={state} prices={price_count}")
            if state != "READY_TO_SUBMIT":
                all_ready = False

        if all_ready:
            print("\nOK: subscriptions READY_TO_SUBMIT — StoreKit sandbox should load products within ~15–60 min.")
        else:
            print("\nWARN: one or more subscriptions still not READY_TO_SUBMIT")
            return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except httpx.HTTPStatusError as exc:
        print(exc.response.text[:800], file=sys.stderr)
        raise SystemExit(1) from exc
