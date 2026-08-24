#!/usr/bin/env python3
"""Semantic validation helpers for Android store screenshot capture."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import Iterable

PACKAGE = "com.hiair"

CRASH_PATTERNS = (
    re.compile(r"has stopped", re.I),
    re.compile(r"keeps stopping", re.I),
    re.compile(r"isn't responding", re.I),
    re.compile(r"Application Error", re.I),
    re.compile(r"Process system isn't responding", re.I),
)

LAUNCHER_HINTS = (
    "com.google.android.apps.nexuslauncher",
    "com.android.launcher",
    "launcher3",
)

ERROR_HINTS = (
    "common.error.title",
    "connection",
    "Unable to connect",
    "Catalog unavailable",
    "prices are unavailable",
    "catalog_unavailable",
    "taxonomy_failed",
    "insights.loading",
    "symptoms.taxonomy_loading",
)

PAYWALL_UNAVAILABLE_HINTS = (
    "prices are unavailable",
    "catalog_unavailable",
    "Google Play prices",
)

PROGRESS_OVERFLOW = re.compile(r"\b(\d{2,})/(\d+)\b")

RAW_KEY = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$")
SCREEN_MARKER = re.compile(r"^screen\.[a-z]+\.root$")


@dataclass
class ValidationResult:
    ok: bool
    detected_marker: str | None
    foreground_package: str | None
    errors: list[str]

    def to_dict(self) -> dict:
        return {
            "semantic_validation_ok": self.ok,
            "detected_marker": self.detected_marker,
            "foreground_package": self.foreground_package,
            "errors": self.errors,
        }


def _local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def iter_nodes(root: ET.Element) -> Iterable[ET.Element]:
    yield root
    for child in root.iter():
        yield child


def find_marker(root: ET.Element, expected: str) -> str | None:
    for node in iter_nodes(root):
        for attr in ("content-desc", "resource-id", "text"):
            val = node.attrib.get(attr, "").strip()
            if val == expected:
                return expected
    return None


def collect_visible_text(root: ET.Element) -> list[str]:
    texts: list[str] = []
    for node in iter_nodes(root):
        for attr in ("text", "content-desc"):
            val = node.attrib.get(attr, "").strip()
            if val:
                texts.append(val)
    return texts


def validate_hierarchy(
    xml_text: str,
    *,
    expected_marker: str,
    foreground_package: str | None,
    allow_loading: bool = False,
) -> ValidationResult:
    errors: list[str] = []
    detected: str | None = None

    if foreground_package != PACKAGE:
        errors.append(f"foreground package expected {PACKAGE}, got {foreground_package}")

    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as exc:
        return ValidationResult(False, None, foreground_package, [f"invalid hierarchy xml: {exc}"])

    detected = find_marker(root, expected_marker)
    if not detected:
        errors.append(f"missing screen marker {expected_marker}")

    joined = "\n".join(collect_visible_text(root))
    for pat in CRASH_PATTERNS:
        if pat.search(joined):
            errors.append(f"crash dialog pattern: {pat.pattern}")

    lower_joined = joined.lower()
    for node in iter_nodes(root):
        pkg = node.attrib.get("package", "")
        if pkg and any(hint in pkg for hint in LAUNCHER_HINTS):
            errors.append(f"launcher UI detected in hierarchy package={pkg}")
            break
    if not any("launcher UI" in e for e in errors):
        if any(hint in lower_joined for hint in LAUNCHER_HINTS):
            errors.append("launcher UI detected in hierarchy")

    if not allow_loading:
        for hint in ERROR_HINTS:
            if hint.lower() in lower_joined:
                errors.append(f"error/loading UI detected: {hint}")

    for text in collect_visible_text(root):
        if SCREEN_MARKER.match(text):
            continue
        if RAW_KEY.match(text) and not text.startswith("com."):
            errors.append(f"raw localization key visible: {text}")
            break

    return ValidationResult(len(errors) == 0, detected, foreground_package, errors)


def validate_screen_business_rules(
    *,
    screen: str,
    texts: list[str],
    allow_paywall_error_state: bool = False,
) -> list[str]:
    errors: list[str] = []
    joined = "\n".join(texts)
    lower = joined.lower()

    if screen == "dashboard":
        if not re.search(r"\b\d{1,3}\b", joined):
            errors.append("dashboard missing risk score")
        if "aqi" not in lower and "metric_aqi" not in lower:
            if not re.search(r"\b\d{2,3}\b", joined):
                errors.append("dashboard missing AQI/metrics")

    if screen == "insights":
        for match in PROGRESS_OVERFLOW.finditer(joined):
            numerator = int(match.group(1))
            denominator = int(match.group(2))
            if numerator > denominator:
                errors.append(f"insights impossible progress {numerator}/{denominator}")

    if screen == "settings":
        if re.search(r"\b-\b", joined) and "ai_range" in lower:
            errors.append("settings placeholder dash detected")
        if "connect" in lower and "disconnect" in lower:
            errors.append("settings shows both Connect and Disconnect")

    if screen == "paywall" and not allow_paywall_error_state:
        for hint in PAYWALL_UNAVAILABLE_HINTS:
            if hint.lower() in lower:
                errors.append(f"paywall catalog unavailable: {hint}")
        if "terms" not in lower and "paywall.terms" not in joined:
            errors.append("paywall missing Terms disclosure")
        if "privacy" not in lower and "paywall.privacy" not in joined:
            errors.append("paywall missing Privacy disclosure")

    if screen == "onboarding":
        if "next" not in lower and "onboarding.next" not in joined:
            errors.append("onboarding missing primary CTA")

    return errors


def validate_hierarchy_with_business_rules(
    xml_text: str,
    *,
    expected_marker: str,
    foreground_package: str | None,
    screen: str,
    allow_loading: bool = False,
    allow_paywall_error_state: bool = False,
) -> ValidationResult:
    base = validate_hierarchy(
        xml_text,
        expected_marker=expected_marker,
        foreground_package=foreground_package,
        allow_loading=allow_loading,
    )
    if not base.ok:
        return base
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as exc:
        return ValidationResult(False, base.detected_marker, foreground_package, [f"invalid hierarchy xml: {exc}"])
    business_errors = validate_screen_business_rules(
        screen=screen,
        texts=collect_visible_text(root),
        allow_paywall_error_state=allow_paywall_error_state,
    )
    errors = base.errors + business_errors
    return ValidationResult(len(errors) == 0, base.detected_marker, foreground_package, errors)
