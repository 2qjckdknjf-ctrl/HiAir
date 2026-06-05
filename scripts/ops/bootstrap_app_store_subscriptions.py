#!/usr/bin/env python3
"""Create HiAir Premium subscription group + monthly/yearly products in App Store Connect."""

from __future__ import annotations

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
REVIEW_NOTE = "HiAir Premium unlocks family profiles and extended air-quality insights. Sandbox tester for review."
PRODUCTS = (
    ("HiAir Premium Monthly", "com.hiair.premium.monthly", "ONE_MONTH", 1, 4.99),
    ("HiAir Premium Yearly", "com.hiair.premium.yearly", "ONE_YEAR", 2, 39.99),
)
LOCALES = (
    ("en-US", "HiAir Premium", "Wellness air-quality guidance (not medical advice)."),
    ("ru", "HiAir Premium", "Wellness-напоминания о воздухе (не медицинский совет)."),
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


def _app_id(client: httpx.Client) -> str:
    r = client.get(
        "https://api.appstoreconnect.apple.com/v1/apps",
        params={"filter[bundleId]": BUNDLE_ID},
    )
    r.raise_for_status()
    data = r.json().get("data") or []
    if not data:
        raise SystemExit(f"No app for bundle {BUNDLE_ID}")
    return data[0]["id"]


def _existing_group_id(client: httpx.Client, app_id: str) -> str | None:
    r = client.get(
        f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/subscriptionGroups",
        params={"limit": 50},
    )
    r.raise_for_status()
    for item in r.json().get("data") or []:
        name = (item.get("attributes") or {}).get("referenceName", "")
        if name == GROUP_NAME:
            return item["id"]
    return None


def _create_group(client: httpx.Client, app_id: str) -> str:
    body = {
        "data": {
            "type": "subscriptionGroups",
            "attributes": {"referenceName": GROUP_NAME},
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
            },
        }
    }
    r = client.post("https://api.appstoreconnect.apple.com/v1/subscriptionGroups", json=body)
    r.raise_for_status()
    return r.json()["data"]["id"]


def _subscriptions_by_product(client: httpx.Client, group_id: str) -> dict[str, dict]:
    r = client.get(
        f"https://api.appstoreconnect.apple.com/v1/subscriptionGroups/{group_id}/subscriptions",
        params={"limit": 50},
    )
    r.raise_for_status()
    out: dict[str, dict] = {}
    for item in r.json().get("data") or []:
        attrs = item.get("attributes") or {}
        pid = attrs.get("productId")
        if pid:
            out[pid] = item
    return out


def _existing_product_ids(client: httpx.Client, group_id: str) -> set[str]:
    return set(_subscriptions_by_product(client, group_id).keys())


def _create_subscription(
    client: httpx.Client,
    group_id: str,
    name: str,
    product_id: str,
    period: str,
    group_level: int,
) -> None:
    body = {
        "data": {
            "type": "subscriptions",
            "attributes": {
                "name": name,
                "productId": product_id,
                "subscriptionPeriod": period,
                "groupLevel": group_level,
                "familySharable": False,
            },
            "relationships": {
                "group": {"data": {"type": "subscriptionGroups", "id": group_id}},
            },
        }
    }
    r = client.post("https://api.appstoreconnect.apple.com/v1/subscriptions", json=body)
    r.raise_for_status()
    print(f"  created subscription {product_id} id={r.json()['data']['id']}")


def _add_localization(
    client: httpx.Client,
    subscription_id: str,
    locale: str,
    name: str,
    description: str,
) -> None:
    body = {
        "data": {
            "type": "subscriptionLocalizations",
            "attributes": {"name": name, "locale": locale, "description": description},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": subscription_id}},
            },
        }
    }
    r = client.post("https://api.appstoreconnect.apple.com/v1/subscriptionLocalizations", json=body)
    if r.status_code == 409:
        return
    r.raise_for_status()
    print(f"    localization {locale}")


def _find_usa_price_point(client: httpx.Client, subscription_id: str, target: float) -> str | None:
    r = client.get(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}/pricePoints",
        params={"filter[territory]": "USA", "limit": 200},
    )
    r.raise_for_status()
    best_id: str | None = None
    best_diff = 1e9
    for item in r.json().get("data") or []:
        attrs = item.get("attributes") or {}
        for field in ("customerPrice", "proceeds"):
            raw = attrs.get(field)
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


def _ensure_group_localizations(client: httpx.Client, group_id: str) -> None:
    for locale, name, _desc in LOCALES:
        body = {
            "data": {
                "type": "subscriptionGroupLocalizations",
                "attributes": {"name": name, "locale": locale, "customAppName": "HiAir"},
                "relationships": {
                    "subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": group_id}},
                },
            }
        }
        r = client.post(
            "https://api.appstoreconnect.apple.com/v1/subscriptionGroupLocalizations",
            json=body,
        )
        if r.status_code not in (201, 409):
            r.raise_for_status()


def _patch_review_note(client: httpx.Client, subscription_id: str) -> None:
    body = {
        "data": {
            "type": "subscriptions",
            "id": subscription_id,
            "attributes": {"reviewNote": REVIEW_NOTE},
        }
    }
    r = client.patch(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}",
        json=body,
    )
    r.raise_for_status()


def _all_territory_ids(client: httpx.Client) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    url: str | None = "https://api.appstoreconnect.apple.com/v1/territories"
    params: dict[str, object] | None = {"limit": 200}
    while url:
        r = client.get(url, params=params)
        r.raise_for_status()
        payload = r.json()
        for item in payload.get("data") or []:
            out.append({"type": "territories", "id": item["id"]})
        url = (payload.get("links") or {}).get("next")
        params = None
    return out


def _ensure_availability(client: httpx.Client, subscription_id: str, product_id: str) -> None:
    r = client.get(
        f"https://api.appstoreconnect.apple.com/v1/subscriptions/{subscription_id}/subscriptionAvailability"
    )
    if r.status_code == 200 and r.json().get("data"):
        print(f"    availability already set")
        return
    territories = _all_territory_ids(client)
    body = {
        "data": {
            "type": "subscriptionAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": subscription_id}},
                "availableTerritories": {"data": territories},
            },
        }
    }
    r = client.post("https://api.appstoreconnect.apple.com/v1/subscriptionAvailabilities", json=body)
    if r.status_code in (201, 409):
        print(f"    availability {len(territories)} territories")
        return
    r.raise_for_status()


def _set_usa_price(client: httpx.Client, subscription_id: str, target_usd: float) -> None:
    point_id = _find_usa_price_point(client, subscription_id, target_usd)
    if not point_id:
        print(f"    WARN: no USA price point near ${target_usd}")
        return
    body = {
        "data": {
            "type": "subscriptionPrices",
            "attributes": {"preserveCurrentPrice": False},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": subscription_id}},
                "subscriptionPricePoint": {
                    "data": {"type": "subscriptionPricePoints", "id": point_id}
                },
            },
        }
    }
    r = client.post("https://api.appstoreconnect.apple.com/v1/subscriptionPrices", json=body)
    if r.status_code in (409, 422):
        print(f"    price USA ~${target_usd} (already set or pending)")
        return
    r.raise_for_status()
    print(f"    price USA ~${target_usd}")


def _finalize_subscription(
    client: httpx.Client,
    subscription_id: str,
    product_id: str,
    target_usd: float,
) -> None:
    print(f"  finalize {product_id}")
    for locale, name, description in LOCALES:
        _add_localization(client, subscription_id, locale, name, description)
    _patch_review_note(client, subscription_id)
    _ensure_availability(client, subscription_id, product_id)
    _set_usa_price(client, subscription_id, target_usd)


def main() -> int:
    issuer = _issuer()
    key_id, pem = _key()
    headers = {"Authorization": f"Bearer {_token(key_id, pem, issuer)}"}
    with httpx.Client(timeout=90.0, headers=headers) as client:
        app_id = _app_id(client)
        print(f"App {BUNDLE_ID} id={app_id}")
        group_id = _existing_group_id(client, app_id)
        if group_id:
            print(f"Group exists: {GROUP_NAME} id={group_id}")
        else:
            group_id = _create_group(client, app_id)
            print(f"Created group {GROUP_NAME} id={group_id}")

        _ensure_group_localizations(client, group_id)
        subs = _subscriptions_by_product(client, group_id)
        for name, product_id, period, level, target_usd in PRODUCTS:
            if product_id not in subs:
                _create_subscription(client, group_id, name, product_id, period, level)
                subs = _subscriptions_by_product(client, group_id)
            sub_id = subs[product_id]["id"]
            _finalize_subscription(client, sub_id, product_id, target_usd)

    print("\nNext in App Store Connect:")
    print("  1) Monetization → Subscriptions → submit for review if required")
    print("  2) Link subscriptions to the TestFlight app version (App version → In-App Purchases)")
    print("  3) Wait ~15–60 min, then retry Premium in the app (sandbox Apple ID)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except httpx.HTTPStatusError as exc:
        print(exc.response.text[:800], file=sys.stderr)
        raise SystemExit(1) from exc
