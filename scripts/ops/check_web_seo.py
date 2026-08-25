#!/usr/bin/env python3
"""Fail closed when the static HiAir website loses basic SEO integrity."""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "web"
ORIGIN = "https://hiair.io"


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.title = ""
        self.description = ""
        self.canonical = ""
        self.h1_count = 0
        self.links: list[str] = []
        self.json_ld: list[str] = []
        self._capture_title = False
        self._capture_json_ld = False
        self._buffer: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag == "title":
            self._capture_title = True
        elif tag == "meta" and values.get("name") == "description":
            self.description = values.get("content", "") or ""
        elif tag == "link" and values.get("rel") == "canonical":
            self.canonical = values.get("href", "") or ""
        elif tag == "h1":
            self.h1_count += 1
        elif tag == "a" and values.get("href"):
            self.links.append(values["href"] or "")
        elif tag == "script" and values.get("type") == "application/ld+json":
            self._capture_json_ld = True
            self._buffer = []

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._capture_title = False
        elif tag == "script" and self._capture_json_ld:
            self._capture_json_ld = False
            self.json_ld.append("".join(self._buffer).strip())

    def handle_data(self, data: str) -> None:
        if self._capture_title:
            self.title += data
        if self._capture_json_ld:
            self._buffer.append(data)


def path_for_url(url: str) -> Path:
    parsed = urlparse(url)
    relative = parsed.path.strip("/")
    return WEB / relative / "index.html" if relative else WEB / "index.html"


def main() -> int:
    errors: list[str] = []
    sitemap_path = WEB / "sitemap.xml"
    root = ET.parse(sitemap_path).getroot()
    namespace = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    urls = [node.text or "" for node in root.findall("s:url/s:loc", namespace)]
    if len(urls) < 10:
        errors.append(f"sitemap must expose at least 10 useful URLs, found {len(urls)}")

    titles: dict[str, str] = {}
    descriptions: dict[str, str] = {}
    indexed_files: set[Path] = set()

    for url in urls:
        if not url.startswith(f"{ORIGIN}/"):
            errors.append(f"non-canonical sitemap origin: {url}")
            continue
        page_path = path_for_url(url)
        indexed_files.add(page_path.resolve())
        if not page_path.is_file():
            errors.append(f"sitemap URL has no HTML file: {url}")
            continue

        text = page_path.read_text(encoding="utf-8")
        parser = PageParser()
        parser.feed(text)
        rel = page_path.relative_to(WEB)

        if parser.h1_count != 1:
            errors.append(f"{rel}: expected exactly one h1, found {parser.h1_count}")
        if not parser.title.strip():
            errors.append(f"{rel}: missing title")
        elif parser.title in titles:
            errors.append(f"{rel}: duplicate title with {titles[parser.title]}")
        else:
            titles[parser.title] = str(rel)
        if not parser.description.strip():
            errors.append(f"{rel}: missing meta description")
        elif parser.description in descriptions:
            errors.append(f"{rel}: duplicate description with {descriptions[parser.description]}")
        else:
            descriptions[parser.description] = str(rel)
        if parser.canonical != url:
            errors.append(f"{rel}: canonical {parser.canonical!r} does not match {url!r}")
        if "Draft for closed beta" in text or "Official support and legal contact will be published" in text:
            errors.append(f"{rel}: public placeholder copy remains")

        for payload in parser.json_ld:
            try:
                json.loads(payload)
            except json.JSONDecodeError as exc:
                errors.append(f"{rel}: invalid JSON-LD: {exc}")

        for href in parser.links:
            if not href.startswith("/") or href.startswith("//"):
                continue
            clean = href.split("#", 1)[0].split("?", 1)[0]
            if not clean:
                continue
            target = path_for_url(f"{ORIGIN}{clean}")
            if not target.exists() and not (WEB / clean.lstrip("/")).exists():
                errors.append(f"{rel}: broken internal link {href}")

    orphan_candidates = {
        path.resolve()
        for path in WEB.glob("**/index.html")
        if path.parent.name not in {"privacy", "terms"} or path.resolve() in indexed_files
    }
    for orphan in sorted(orphan_candidates - indexed_files):
        errors.append(f"indexable HTML missing from sitemap: {orphan.relative_to(WEB)}")

    robots = (WEB / "robots.txt").read_text(encoding="utf-8")
    if "Sitemap: https://hiair.io/sitemap.xml" not in robots:
        errors.append("robots.txt does not advertise the canonical sitemap")
    if re.search(r"(?im)^\s*Disallow:\s*/\s*$", robots):
        errors.append("robots.txt blocks the whole site")

    if errors:
        print("WEB SEO CHECK: FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"WEB SEO CHECK: PASS ({len(urls)} sitemap URLs, {len(titles)} unique titles)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
